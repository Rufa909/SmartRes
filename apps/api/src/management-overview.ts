import {z} from 'zod';
import type {Pool,RowDataPacket} from 'mysql2/promise';

const DAY=86400000;
const vnDate=(time:number)=>new Date(time+7*3600000).toISOString().slice(0,10);
const date=z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(value=>{
  const timestamp=Date.parse(`${value}T00:00:00Z`);
  return Number.isFinite(timestamp) && new Date(timestamp).toISOString().slice(0,10)===value && value>='2000-01-01' && value<='2099-12-31';
},'Ngày không hợp lệ.');

export function overviewPeriod(query:unknown,now=Date.now()) {
  const today=vnDate(now);
  const input=z.object({from:date.default(vnDate(now-6*DAY)),to:date.default(today)}).parse(query);
  const start=Date.parse(`${input.from}T00:00:00+07:00`);
  const end=Date.parse(`${input.to}T00:00:00+07:00`)+DAY;
  const days=(end-start)/DAY;
  if(days<1 || days>366)throw new z.ZodError([{code:'custom',path:['to'],message:'Khoảng ngày phải từ 1 đến 366 ngày.'}]);
  return {...input,start:start/1000,end:end/1000,days};
}

export async function readManagementOverview(db:Pool,query:unknown) {
  const period=overviewPeriod(query);
  const c=await db.getConnection();
  // FROM_UNIXTIME sử dụng múi giờ session MySQL để so sánh TIMESTAMP đúng thời điểm.
  const filter='h.paid_at>=FROM_UNIXTIME(?) AND h.paid_at<FROM_UNIXTIME(?)';
  const range=[period.start,period.end];
  try {
    await c.beginTransaction();
    const [totals]=await c.query<RowDataPacket[]>(`SELECT COUNT(*) AS invoiceCount,COALESCE(SUM(h.total_amount),0) AS revenue,
      COALESCE(SUM(COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(h.snapshot,'$.discountAmount')) AS DECIMAL(12,2)),0)),0) AS discountAmount
      FROM cashier_invoices h WHERE ${filter}`,range);
    const [previous]=await c.query<RowDataPacket[]>(`SELECT COALESCE(SUM(h.total_amount),0) AS revenue FROM cashier_invoices h WHERE ${filter}`,
      [period.start-period.days*86400,period.start]);
    // Nhóm ngày Việt Nam từ epoch, không phụ thuộc cấu hình múi giờ máy MySQL.
    const [days]=await c.query<RowDataPacket[]>(`SELECT DATE_FORMAT(TIMESTAMPADD(SECOND,UNIX_TIMESTAMP(h.paid_at)+25200,'1970-01-01 00:00:00'),'%Y-%m-%d') AS date,
      SUM(h.total_amount) AS revenue,COUNT(*) AS invoiceCount FROM cashier_invoices h WHERE ${filter} GROUP BY date ORDER BY date`,range);
    const [payments]=await c.query<RowDataPacket[]>(`SELECT payment_method AS method,COUNT(*) AS invoiceCount,SUM(total_amount) AS revenue
      FROM cashier_invoices h WHERE ${filter} GROUP BY payment_method ORDER BY revenue DESC`,range);
    const [top]=await c.query<RowDataPacket[]>(`SELECT i.menuItemId,COALESCE(i.name,'Món không tên') AS name,SUM(i.quantity) AS quantity,
      SUM(i.quantity*i.unitPrice) AS grossAmount FROM cashier_invoices h
      JOIN JSON_TABLE(h.snapshot,'$.items[*]' COLUMNS(
        menuItemId BIGINT PATH '$.menuItemId' NULL ON EMPTY,
        name VARCHAR(160) PATH '$.name' NULL ON EMPTY,
        quantity INT PATH '$.quantity' DEFAULT '0' ON EMPTY,
        unitPrice DECIMAL(12,2) PATH '$.unitPrice' DEFAULT '0' ON EMPTY
      )) AS i ON TRUE WHERE ${filter} GROUP BY i.menuItemId,i.name ORDER BY quantity DESC,grossAmount DESC,name LIMIT 5`,range);
    const [recent]=await c.query<RowDataPacket[]>(`SELECT id AS historyId,invoice_code AS invoiceCode,table_code AS tableCode,
      total_amount AS totalAmount,payment_method AS paymentMethod,UNIX_TIMESTAMP(paid_at) AS paidEpoch
      FROM cashier_invoices h WHERE ${filter} ORDER BY paid_at DESC,id DESC LIMIT 5`,range);
    const [tables]=await c.query<RowDataPacket[]>(`SELECT COUNT(*) AS totalTables,
      COALESCE(SUM(status='available'),0) AS availableTables,COALESCE(SUM(status='dining'),0) AS diningTables,
      COALESCE(SUM(status='waiting_payment'),0) AS waitingPaymentTables,
      COALESCE(SUM(IF(status IN ('dining','waiting_payment'),guests,0)),0) AS guests
      FROM restaurant_tables WHERE status<>'disabled'`);
    const [unpaid]=await c.query<RowDataPacket[]>(`SELECT COALESCE(SUM(o.total_amount),0) AS amount FROM orders o
      JOIN restaurant_tables t ON t.id=o.table_id WHERE o.payment_status='unpaid' AND o.status<>'cancelled' AND t.status IN ('dining','waiting_payment')`);
    const [kitchen]=await c.query<RowDataPacket[]>(`SELECT COALESCE(SUM(IF(i.status IN ('preparing','cooking'),i.quantity,0)),0) AS pendingKitchen,
      COALESCE(SUM(IF(i.status='completed',i.quantity,0)),0) AS readyToServe FROM order_items i
      JOIN orders o ON o.id=i.order_id WHERE o.payment_status='unpaid' AND o.status<>'cancelled'`);
    const [menu]=await c.query<RowDataPacket[]>('SELECT COUNT(*) AS outOfStock FROM menu_items WHERE is_available=0');
    await c.commit();
    const revenue=Number(totals[0].revenue),invoiceCount=Number(totals[0].invoiceCount),previousRevenue=Number(previous[0].revenue);
    const daily=Array.from({length:period.days},(_,index)=>{
      const key=vnDate((period.start+index*86400)*1000);
      const day=days.find(d=>d.date===key);
      return {date:key,revenue:Number(day?.revenue ?? 0),invoiceCount:Number(day?.invoiceCount ?? 0)};
    });
    const operations=Object.fromEntries(Object.entries({...tables[0],...kitchen[0],...menu[0],unpaidAmount:unpaid[0].amount}).map(([key,value])=>[key,Number(value)]));
    return {
      generatedAt:new Date().toISOString(),period:{from:period.from,to:period.to,days:period.days,timezone:'Asia/Ho_Chi_Minh'},
      summary:{revenue,invoiceCount,averageBill:invoiceCount?Math.round(revenue/invoiceCount):0,discountAmount:Number(totals[0].discountAmount),previousRevenue,
        changePercent:previousRevenue>0?Math.round((revenue-previousRevenue)/previousRevenue*10000)/100:null},
      daily,operations,
      paymentMethods:payments.map(p=>({...p,revenue:Number(p.revenue),invoiceCount:Number(p.invoiceCount)})),
      topItems:top.map(i=>({...i,menuItemId:i.menuItemId===null?null:Number(i.menuItemId),quantity:Number(i.quantity),grossAmount:Number(i.grossAmount)})),
      recentInvoices:recent.map(i=>({...i,historyId:Number(i.historyId),totalAmount:Number(i.totalAmount),paidAt:new Date(Number(i.paidEpoch)*1000).toISOString()})),
    };
  } catch(e){await c.rollback();throw e;} finally{c.release();}
}

"use client";

import { useEffect, useRef, useState, type ReactNode } from 'react';

// QR dẫn thẳng vào thực đơn; phiên được cấp tự động phía sau giao diện.
export function CustomerAccess({tableCode, children}: {
  tableCode: string;
  children: (token: string, expired: () => void) => ReactNode;
}) {
  const key=`smartres-customer:${tableCode}`;
  const [token,setToken]=useState('');
  const [message,setMessage]=useState('Đang kết nối bàn...');
  const [retry,setRetry]=useState(0);
  const ended=useRef(false);
  function expired() {
    ended.current=true;
    try {sessionStorage.removeItem(key);} catch {}
    setToken('');
    setMessage('Lượt ăn đã kết thúc. Quét lại QR trên bàn để bắt đầu lượt mới.');
  }
  useEffect(() => {
    let active=true;
    let checking=false;
    let current='';
    try {current=sessionStorage.getItem(key) || '';} catch {}
    async function connect() {
      if (checking || ended.current) return;
      checking=true;
      try {
        if (current) {
          const checked=await fetch(`/api/customer/customer-sessions/check/${encodeURIComponent(tableCode)}`,{
            headers:{Authorization:`Bearer ${current}`},cache:'no-store',signal:AbortSignal.timeout(10000),
          });
          if (!active) return;
          if (checked.ok) {setToken(current);setMessage('');return;}
          if (checked.status===401) {
            current='';
            try {sessionStorage.removeItem(key);} catch {}
            if (token) {expired();return;}
          } else throw new Error('Không kết nối được bàn. Hãy kiểm tra Wi-Fi nhà hàng.');
        }
        const response=await fetch('/api/customer/customer-sessions/join',{
          method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({tableCode}),
          signal:AbortSignal.timeout(10000),
        });
        if (!response.headers.get('content-type')?.includes('application/json')) throw new Error('Hãy kết nối Wi-Fi nhà hàng để gọi món.');
        const data=await response.json() as {token?:string;message?:string};
        if (!active) return;
        if (!response.ok || !data.token) throw new Error(data.message || 'Chưa kết nối được bàn.');
        current=data.token;
        try {sessionStorage.setItem(key,current);} catch {}
        setToken(current);setMessage('');
      } catch(e) {
        if (active) setMessage(e instanceof Error ? e.message : 'Chưa kết nối được bàn. Vui lòng thử lại.');
      } finally {checking=false;}
    }
    void connect();
    const timer=setInterval(connect,15000);
    window.addEventListener('focus',connect);
    return () => {active=false;clearInterval(timer);window.removeEventListener('focus',connect);};
  },[key,tableCode,retry,token]);
  return <>
    {message && <div role="status" className="flex flex-wrap items-center justify-center gap-3 bg-amber-50 px-4 py-3 text-sm text-amber-900">
      <span>{message}</span>
      {!ended.current && <button className="font-bold underline" onClick={()=>setRetry(n=>n+1)}>Thử kết nối lại</button>}
    </div>}
    {children(token,expired)}
  </>;
}

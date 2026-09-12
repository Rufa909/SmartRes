import dotenv from "dotenv";
import { z } from "zod";

dotenv.config({ path: "../../.env" });
dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.string().default("development"),
  API_PORT: z.coerce.number().default(4000),
  MYSQL_HOST: z.string().default("localhost"),
  MYSQL_PORT: z.coerce.number().default(3306),
  MYSQL_DATABASE: z.string().default("smartres"),
  MYSQL_USER: z.string().default("smartres"),
  MYSQL_PASSWORD: z.string().default("smartres_password"),
  REDIS_URL: z.string().default("redis://localhost:6379"),
  AI_SERVICE_URL: z.string().default("http://localhost:8000"),
  JWT_SECRET: z.string().default("change_me"),
  SEPAY_API_KEY: z.string().default(""),
  SEPAY_WEBHOOK_SECRET: z.string().default("")
});

export const env = envSchema.parse(process.env);


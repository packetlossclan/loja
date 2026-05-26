import { ContainerRegistrationKeys, defineConfig, loadEnv } from "@medusajs/framework/utils"

loadEnv(process.env.NODE_ENV || "development", process.cwd())

const mercadoPagoAccessToken = process.env.MERCADOPAGO_ACCESS_TOKEN
const mercadoPagoWebhookSecret = process.env.MERCADOPAGO_WEBHOOK_SECRET
const enableMercadoPago = Boolean(mercadoPagoAccessToken)

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: process.env.REDIS_URL,
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    },
  },
  plugins: enableMercadoPago
    ? [
        {
          resolve: "@nicogorga/medusa-payment-mercadopago",
          options: {
            accessToken: mercadoPagoAccessToken,
            webhookSecret: mercadoPagoWebhookSecret,
          },
        },
      ]
    : [],
  modules: enableMercadoPago
    ? [
        {
          resolve: "@medusajs/medusa/payment",
          options: {
            providers: [
              {
                resolve: "@nicogorga/medusa-payment-mercadopago/providers/mercado-pago",
                id: "mercadopago",
                options: {
                  accessToken: mercadoPagoAccessToken,
                  webhookSecret: mercadoPagoWebhookSecret,
                },
                dependencies: [ContainerRegistrationKeys.LOGGER],
              },
            ],
          },
        },
      ]
    : [],
})

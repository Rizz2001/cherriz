# Cherriz - Roadmap & Contexto del Proyecto (Inspirado en Fina Partner)

## Descripción General
Cherriz es un sistema administrativo y de Punto de Venta (POS) en la nube (SaaS), multi-tenant, diseñado específicamente para PyMEs (bodegones, restaurantes, ferreterías, tiendas de ropa, etc.).
Su objetivo es automatizar procesos, eliminar el uso de hojas de cálculo complejas y ofrecer control total sobre las ventas, inventario y finanzas en tiempo real.

## Stack Tecnológico
- **Frontend / POS:** Flutter (Dart) - Permite acceso desde celular, tablet y PC (Multiplataforma).
- **Backend / Base de Datos:** Supabase (PostgreSQL) con sincronización en tiempo real.
- **Diseño UI:** Estilo iOS (Cupertino, Glassmorphism, bordes redondeados, intuitivo y moderno).

## Funcionalidades Core (Características del Sistema)
- **Gestión de Inventario Avanzada:** 
  - Control de entradas y salidas en tiempo real.
  - Alertas automáticas de stock mínimo.
  - Soporte para tallas, colores, referencias o modelos (ideal para ropa y repuestos).
  - Manejo de fechas de vencimiento (ideal para alimentos).
  - Recetaje: Carga de recetas para descontar ingredientes automáticamente al vender un plato (para restaurantes).
- **Resumen Financiero y Tesorería:** 
  - Panel en tiempo real con estadísticas clave (facturación, utilidad mensual, ingresos vs gastos).
  - Control de cuentas bancarias y flujo de caja en efectivo.
  - Gestión de Cuentas por Cobrar y Cuentas por Pagar.
- **Facturación y Punto de Venta (POS):** 
  - Soporte para ventas rápidas, control de mesas, mesoneros y repartidores (delivery).
  - Facturación adaptada al entorno multimoneda (Cuentas claras en Bs. y $).
  - Registro de múltiples métodos de pago (Punto de venta, pago móvil, Zelle, efectivo divisas, etc.).
  - Cálculo de impuestos locales (IVA, IGTF).
- **Marketing y Clientes:**
  - Base de datos detallada de clientes con estadísticas de comportamiento de compra.
  - Módulo para campañas de marketing (envío de SMS a clientes).
- **Importación y Reportes:**
  - Importar/Exportar data de inventario y balances vía Excel y PDF.

## Fases de Desarrollo
1. **El Núcleo y Base de Datos:** Estructura Multi-tenant, tablas maestras, RLS y autenticación.
2. **Administración y Finanzas:** Configuración de cuentas, inventario avanzado (recetas, tallas, vencimientos), cuentas por cobrar/pagar, manejo de Tasa de Cambio.
3. **Punto de Venta (POS) y Flujo de Trabajo:** Interfaz de caja, cálculo multimoneda, mesas/repartidores y descuentos de inventario.
4. **CRM y Marketing:** Gestión de clientes, reportes PDF/Excel, y alertas SMS.
5. **Panel Super-Admin:** Gestión global de suscripciones de los negocios clientes (Planes mensuales/anuales).

## Reglas de Arquitectura
- **Multi-tenant RLS:** Toda tabla (excepto companies) debe tener un `company_id`. Privacidad absoluta entre negocios.
- **Roles y Usuarios Ilimitados:** `super_admin` (tú), `admin` (dueño), `cashier` (cajeros), `waiter` (mesoneros), etc.
- **Multimoneda:** Todo debe guardar su valor base (USD) y la conversión a moneda local se calcula dinámicamente según la tasa activa.

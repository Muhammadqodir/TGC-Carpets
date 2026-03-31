# TGC Carpets — REST API Documentation

**Base URL:** `https://<host>/api/v1`  
**Authentication:** Laravel Sanctum — Bearer token  
**Content-Type:** `application/json` (unless noted otherwise)

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Products](#2-products)
3. [Clients](#3-clients)
4. [Warehouse Documents](#4-warehouse-documents)
5. [Sales](#5-sales)
6. [Stock](#6-stock)
7. [Common Patterns](#7-common-patterns)
8. [Error Responses](#8-error-responses)

---

## 1. Authentication

### 1.1 Login

Issue a Sanctum personal access token. No authentication required.

```
POST /auth/login
```

**Request Body**

| Field      | Type   | Required | Description            |
|------------|--------|----------|------------------------|
| `email`    | string | Yes      | User e-mail address    |
| `password` | string | Yes      | User password          |

```json
{
  "email": "admin@tgccarpets.com",
  "password": "secret"
}
```

**Response `200 OK`**

```json
{
  "data": {
    "user": {
      "id": 1,
      "name": "Admin User",
      "email": "admin@tgccarpets.com",
      "phone": "+998901234567",
      "role": "admin",
      "is_admin": true,
      "is_warehouse": false,
      "is_seller": false
    },
    "token": "1|PlaXrZabcXYZ..."
  }
}
```

**Response `401 Unauthorized`**

```json
{ "message": "The provided credentials are incorrect." }
```

---

### 1.2 Logout

Revoke the current access token. **Requires authentication.**

```
POST /auth/logout
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Logged out successfully." }
```

---

### 1.3 Authenticated User

Return the currently authenticated user. **Requires authentication.**

```
GET /auth/me
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{
  "data": {
    "id": 1,
    "name": "Admin User",
    "email": "admin@tgccarpets.com",
    "phone": "+998901234567",
    "role": "admin",
    "is_admin": true,
    "is_warehouse": false,
    "is_seller": false
  }
}
```

**User roles:** `admin` | `warehouse` | `seller`

---

## 2. Products

All endpoints require authentication.

### Product Object

| Field       | Type            | Description                                |
|-------------|-----------------|--------------------------------------------|
| `id`        | integer         | Internal ID                                |
| `uuid`      | string (UUID)   | Stable public identifier                   |
| `name`      | string          | Product name                               |
| `sku_code`  | string          | Unique SKU (e.g. `TGC-001`)                |
| `barcode`   | string / null   | Optional barcode                           |
| `length`    | integer         | Carpet length in cm                        |
| `width`     | integer         | Carpet width in cm                         |
| `quality`   | string          | Quality grade (e.g. `premium`, `standard`) |
| `density`   | integer         | Density value                              |
| `color`     | string          | Color label                                |
| `edge`      | string          | Edge finish type                           |
| `unit`      | string          | `piece` or `m2`                            |
| `status`    | string          | `active` or `archived`                     |
| `image_url` | string / null   | Public URL to product image                |
| `stock`     | integer / null  | Current stock level (when loaded)          |
| `created_at`| ISO 8601        |                                            |
| `updated_at`| ISO 8601        |                                            |

---

### 2.1 List Products

```
GET /products
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter  | Type    | Description                              |
|------------|---------|------------------------------------------|
| `search`   | string  | Full-text search on `name` and `sku_code`|
| `sku_code` | string  | Partial match on SKU                     |
| `name`     | string  | Partial match on name                    |
| `quality`  | string  | Exact match on quality                   |
| `color`    | string  | Exact match on color                     |
| `status`   | string  | `active` or `archived`                   |
| `per_page` | integer | Results per page (default: `20`)         |
| `page`     | integer | Page number (default: `1`)               |

**Response `200 OK`**

```json
{
  "data": [
    {
      "id": 1,
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Persian Classic",
      "sku_code": "TGC-001",
      "barcode": "1234567890123",
      "length": 300,
      "width": 200,
      "quality": "premium",
      "density": 800,
      "color": "red",
      "edge": "fringed",
      "unit": "piece",
      "status": "active",
      "image_url": "https://<host>/storage/products/abc.jpg",
      "stock": null,
      "created_at": "2025-01-15T08:00:00.000000Z",
      "updated_at": "2025-01-15T08:00:00.000000Z"
    }
  ],
  "links": { "first": "...", "last": "...", "prev": null, "next": "..." },
  "meta": {
    "current_page": 1,
    "last_page": 5,
    "per_page": 20,
    "total": 98
  }
}
```

---

### 2.2 Create Product

```
POST /products
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Request Body**

| Field     | Type    | Required | Validation                              |
|-----------|---------|----------|-----------------------------------------|
| `name`    | string  | Yes      | max:255                                 |
| `sku_code`| string  | Yes      | max:100, unique                         |
| `barcode` | string  | No       | max:100, unique                         |
| `length`  | integer | Yes      | min:1                                   |
| `width`   | integer | Yes      | min:1                                   |
| `quality` | string  | Yes      | max:100                                 |
| `density` | integer | Yes      | min:1                                   |
| `color`   | string  | Yes      | max:100                                 |
| `edge`    | string  | Yes      | max:100                                 |
| `unit`    | string  | Yes      | `piece` or `m2`                         |
| `status`  | string  | No       | `active` or `archived` (default: `active`) |
| `image`   | file    | No       | jpg, jpeg, png, webp — max 4 MB         |

**Response `201 Created`**

```json
{
  "data": { /* Product Object */ }
}
```

---

### 2.3 Get Product

```
GET /products/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{
  "data": { /* Product Object */ }
}
```

**Response `404 Not Found`**

```json
{ "message": "No query results for model [App\\Models\\Product] {id}." }
```

---

### 2.4 Update Product

Partial updates supported — only send the fields you want to change.

```
POST /products/{id}?_method=PUT
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

> Use `POST` with `_method=PUT` when uploading a file. For JSON-only updates, `PUT /products/{id}` also works.

**Request Body** — Same fields as Create; all are optional (`sometimes|required`).

**Response `200 OK`**

```json
{
  "data": { /* updated Product Object */ }
}
```

---

### 2.5 Delete Product

Soft-deletes (archives) the product.

```
DELETE /products/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Product archived successfully." }
```

---

## 3. Clients

All endpoints require authentication.

### Client Object

| Field          | Type          | Description                        |
|----------------|---------------|------------------------------------|
| `id`           | integer       | Internal ID                        |
| `uuid`         | string (UUID) | Stable public identifier           |
| `contact_name` | string        | Primary contact person             |
| `phone`        | string        | Contact phone number               |
| `shop_name`    | string / null | Store / business name              |
| `region`       | string / null | Geographic region                  |
| `address`      | string / null | Full address                       |
| `notes`        | string / null | Free-form notes                    |
| `created_at`   | ISO 8601      |                                    |
| `updated_at`   | ISO 8601      |                                    |

---

### 3.1 List Clients

```
GET /clients
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter      | Type    | Description                            |
|----------------|---------|----------------------------------------|
| `shop_name`    | string  | Partial match                          |
| `contact_name` | string  | Partial match                          |
| `phone`        | string  | Partial match                          |
| `region`       | string  | Exact match                            |
| `per_page`     | integer | Default: `20`                          |
| `page`         | integer | Default: `1`                           |

**Response `200 OK`** — Paginated list of Client Objects.

---

### 3.2 Create Client

Idempotent — if `external_uuid` is supplied and a matching record already exists, that record is returned (`200`) instead of creating a duplicate.

```
POST /clients
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field           | Type   | Required | Description                              |
|-----------------|--------|----------|------------------------------------------|
| `contact_name`  | string | Yes      | max:255                                  |
| `phone`         | string | Yes      | max:50                                   |
| `shop_name`     | string | No       |                                          |
| `region`        | string | No       |                                          |
| `address`       | string | No       |                                          |
| `notes`         | string | No       |                                          |
| `external_uuid` | UUID   | No       | Client-generated UUID for offline sync   |

**Response `201 Created` / `200 OK` (existing)**

```json
{
  "data": { /* Client Object */ }
}
```

---

### 3.3 Get Client

```
GET /clients/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{
  "data": { /* Client Object */ }
}
```

---

### 3.4 Update Client

```
PUT /clients/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

All fields optional. Same constraints as Create.

**Response `200 OK`**

```json
{
  "data": { /* updated Client Object */ }
}
```

---

### 3.5 Delete Client

```
DELETE /clients/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Client deleted successfully." }
```

---

## 4. Warehouse Documents

A Warehouse Document records a stock movement event (goods in, goods out, return, or adjustment) together with line items. All endpoints require authentication.

### Document Types

| Value        | Meaning                             |
|--------------|-------------------------------------|
| `in`         | Incoming stock (production / purchase) |
| `out`        | Outgoing stock (delivery / transfer)   |
| `return`     | Customer return (increases stock)      |
| `adjustment` | Manual inventory correction            |

### Warehouse Document Object

| Field           | Type            | Description                              |
|-----------------|-----------------|------------------------------------------|
| `id`            | integer         |                                          |
| `uuid`          | string (UUID)   |                                          |
| `external_uuid` | string / null   | Client-generated UUID for offline sync   |
| `type`          | string          | `in`, `out`, `return`, `adjustment`      |
| `document_date` | ISO 8601        | Date of the movement                     |
| `notes`         | string / null   |                                          |
| `user`          | object / null   | `{ id, name }` — who created it          |
| `client`        | object / null   | `{ id, shop_name }` — related client     |
| `items`         | array           | Line items (see below)                   |
| `photos`        | array           | Attached photos (see below)              |
| `created_at`    | ISO 8601        |                                          |
| `updated_at`    | ISO 8601        |                                          |

**Line Item Object**

| Field     | Type    | Description               |
|-----------|---------|---------------------------|
| `id`      | integer |                           |
| `product` | object  | `{ id, name, sku_code, unit }` |
| `quantity`| integer | Quantity moved            |
| `notes`   | string / null |                     |

**Photo Object**

| Field  | Type   | Description       |
|--------|--------|-------------------|
| `id`   | integer|                   |
| `url`  | string | Public image URL  |
| `path` | string | Storage-relative path |

---

### 4.1 List Warehouse Documents

```
GET /warehouse-documents
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter   | Type    | Description                             |
|-------------|---------|---------------------------------------- |
| `type`      | string  | `in`, `out`, `return`, or `adjustment`  |
| `client_id` | integer | Filter by client                        |
| `user_id`   | integer | Filter by user                          |
| `date_from` | date    | `YYYY-MM-DD`                            |
| `date_to`   | date    | `YYYY-MM-DD`                            |
| `per_page`  | integer | Default: `20`                           |
| `page`      | integer | Default: `1`                            |

**Response `200 OK`** — Paginated list of Warehouse Document Objects.

---

### 4.2 Create Warehouse Document

Idempotent — if `external_uuid` already exists, the existing document is returned (`200`).

```
POST /warehouse-documents
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field                 | Type    | Required | Description                              |
|-----------------------|---------|----------|------------------------------------------|
| `type`                | string  | Yes      | `in`, `out`, `return`, `adjustment`      |
| `document_date`       | date    | Yes      | `YYYY-MM-DD`                             |
| `client_id`           | integer | No       | Must exist in `clients` table            |
| `notes`               | string  | No       |                                          |
| `external_uuid`       | UUID    | No       | For offline sync deduplication           |
| `items`               | array   | Yes      | min 1 item                               |
| `items[].product_id`  | integer | Yes      | Must exist in `products` table           |
| `items[].quantity`    | integer | Yes      | min:1                                    |
| `items[].notes`       | string  | No       |                                          |

```json
{
  "type": "in",
  "document_date": "2026-03-29",
  "notes": "March production batch",
  "items": [
    { "product_id": 1, "quantity": 50 },
    { "product_id": 2, "quantity": 30 }
  ]
}
```

**Response `201 Created` / `200 OK` (existing)**

```json
{
  "data": { /* Warehouse Document Object */ }
}
```

---

### 4.3 Get Warehouse Document

```
GET /warehouse-documents/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{
  "data": { /* Warehouse Document Object with items and photos loaded */ }
}
```

---

### 4.4 Update Warehouse Document

Supplying `items` replaces all existing line items and recalculates stock movements.

```
PUT /warehouse-documents/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** — All fields optional (`sometimes|required`):

| Field                 | Type    | Description                              |
|-----------------------|---------|------------------------------------------|
| `type`                | string  | `in`, `out`, `return`, `adjustment`      |
| `document_date`       | date    | `YYYY-MM-DD`                             |
| `client_id`           | integer | nullable                                 |
| `notes`               | string  | nullable                                 |
| `items`               | array   | Replaces all items when provided         |
| `items[].product_id`  | integer |                                          |
| `items[].quantity`    | integer | min:1                                    |
| `items[].notes`       | string  | nullable                                 |

**Response `200 OK`**

```json
{
  "data": { /* updated Warehouse Document Object */ }
}
```

---

### 4.5 Delete Warehouse Document

Deletes the document and **reverses** all associated stock movements.

```
DELETE /warehouse-documents/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Document deleted and stock movements reversed." }
```

---

### 4.6 Upload Photo

Attach a photo to an existing warehouse document.

```
POST /warehouse-documents/{id}/photos
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Request Body**

| Field   | Type | Required | Validation                  |
|---------|------|----------|-----------------------------|
| `photo` | file | Yes      | image, max 10 MB            |

**Response `201 Created`**

```json
{
  "data": {
    "id": 5,
    "url": "https://<host>/storage/warehouse-documents/xyz.jpg",
    "path": "warehouse-documents/xyz.jpg"
  }
}
```

---

### 4.7 Delete Photo

```
DELETE /warehouse-documents/{id}/photos/{photoId}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Photo deleted." }
```

---

## 5. Sales

A Sale records goods sold to a client, automatically creates `out` stock movements for each line item. All endpoints require authentication.

### Payment Statuses

| Value     | Meaning                   |
|-----------|---------------------------|
| `pending` | Not yet paid              |
| `partial` | Partially paid            |
| `paid`    | Fully paid                |

### Sale Object

| Field            | Type          | Description                                |
|------------------|---------------|--------------------------------------------|
| `id`             | integer       |                                            |
| `uuid`           | string (UUID) |                                            |
| `external_uuid`  | string / null | Client-generated UUID for offline sync     |
| `sale_date`      | ISO 8601      |                                            |
| `total_amount`   | decimal       | Sum of all item subtotals                  |
| `payment_status` | string        | `pending`, `partial`, `paid`               |
| `notes`          | string / null |                                            |
| `client`         | object / null | `{ id, shop_name, phone }`                 |
| `user`           | object / null | `{ id, name }` — seller                    |
| `items`          | array         | Line items (see below)                     |
| `created_at`     | ISO 8601      |                                            |
| `updated_at`     | ISO 8601      |                                            |

**Sale Item Object**

| Field      | Type    | Description                     |
|------------|---------|---------------------------------|
| `id`       | integer |                                 |
| `product`  | object  | `{ id, name, sku_code, unit }`  |
| `quantity` | integer |                                 |
| `price`    | decimal | Unit price                      |
| `subtotal` | decimal | `quantity × price`              |

---

### 5.1 List Sales

```
GET /sales
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter        | Type    | Description              |
|------------------|---------|--------------------------|
| `client_id`      | integer | Filter by client         |
| `user_id`        | integer | Filter by seller         |
| `payment_status` | string  | `pending`, `partial`, `paid` |
| `date_from`      | date    | `YYYY-MM-DD`             |
| `date_to`        | date    | `YYYY-MM-DD`             |
| `per_page`       | integer | Default: `20`            |
| `page`           | integer | Default: `1`             |

**Response `200 OK`** — Paginated list of Sale Objects.

---

### 5.2 Create Sale

Idempotent — if `external_uuid` already exists, the existing sale is returned (`200`). Creating a sale automatically generates `out` stock movements.

```
POST /sales
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field                | Type    | Required | Description                            |
|----------------------|---------|----------|----------------------------------------|
| `client_id`          | integer | Yes      | Must exist in `clients` table          |
| `sale_date`          | date    | Yes      | `YYYY-MM-DD`                           |
| `payment_status`     | string  | No       | Default: `pending`                     |
| `notes`              | string  | No       |                                        |
| `external_uuid`      | UUID    | No       | For offline sync deduplication         |
| `items`              | array   | Yes      | min 1 item                             |
| `items[].product_id` | integer | Yes      | Must exist in `products` table         |
| `items[].quantity`   | integer | Yes      | min:1                                  |
| `items[].price`      | decimal | Yes      | min:0, unit price                      |

```json
{
  "client_id": 3,
  "sale_date": "2026-03-29",
  "payment_status": "pending",
  "items": [
    { "product_id": 1, "quantity": 2, "price": 150.00 },
    { "product_id": 4, "quantity": 1, "price": 220.00 }
  ]
}
```

**Response `201 Created` / `200 OK` (existing)**

```json
{
  "data": { /* Sale Object */ }
}
```

---

### 5.3 Get Sale

```
GET /sales/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{
  "data": { /* Sale Object with client, user, and items loaded */ }
}
```

---

### 5.4 Update Sale

Supplying `items` replaces all line items and recalculates stock movements.

```
PUT /sales/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** — All fields optional (`sometimes|required`):

| Field                | Type    | Description                             |
|----------------------|---------|-----------------------------------------|
| `client_id`          | integer |                                         |
| `sale_date`          | date    | `YYYY-MM-DD`                            |
| `payment_status`     | string  | `pending`, `partial`, `paid`            |
| `notes`              | string  | nullable                                |
| `items`              | array   | Replaces all items when provided        |
| `items[].product_id` | integer |                                         |
| `items[].quantity`   | integer | min:1                                   |
| `items[].price`      | decimal | min:0                                   |

**Response `200 OK`**

```json
{
  "data": { /* updated Sale Object */ }
}
```

---

### 5.5 Delete Sale

Deletes the sale and **reverses** all associated stock movements.

```
DELETE /sales/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Sale deleted and stock movements reversed." }
```

---

## 6. Stock

Read-only endpoints available to all authenticated roles.

### 6.1 Current Stock Levels

Returns the live calculated stock per product.

```
GET /stock
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter  | Type    | Description                     |
|------------|---------|---------------------------------|
| `status`   | string  | `active` or `archived`          |
| `name`     | string  | Partial match on product name   |
| `color`    | string  | Exact match on color            |
| `per_page` | integer | Default: `50`                   |
| `page`     | integer | Default: `1`                    |

**Response `200 OK`**

```json
{
  "data": [
    {
      "id": 1,
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Persian Classic",
      "sku_code": "TGC-001",
      "unit": "piece",
      "status": "active",
      "color": "red",
      "quality": "premium",
      "stock_in": 150,
      "stock_out": 42,
      "current_stock": 108
    }
  ],
  "meta": {
    "current_page": 1,
    "last_page": 2,
    "per_page": 50,
    "total": 60
  }
}
```

> **Note:** `stock_in` includes both `in` and `return` warehouse document types. `current_stock = stock_in - stock_out`.

---

### 6.2 Stock Movement History

Paginated, filterable audit log of every stock movement record.

```
GET /stock/movements
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter       | Type    | Description                                         |
|-----------------|---------|-----------------------------------------------------|
| `product_id`    | integer | Filter by product                                   |
| `movement_type` | string  | `in`, `out`, `return`, `adjustment`                 |
| `client_id`     | integer | Filter by associated client                         |
| `user_id`       | integer | Filter by user who recorded it                      |
| `date_from`     | date    | `YYYY-MM-DD`                                        |
| `date_to`       | date    | `YYYY-MM-DD`                                        |
| `per_page`      | integer | Default: `50`                                       |
| `page`          | integer | Default: `1`                                        |

**Response `200 OK`** — Paginated list of Stock Movement Objects.

### Stock Movement Object

| Field                   | Type          | Description                               |
|-------------------------|---------------|-------------------------------------------|
| `id`                    | integer       |                                           |
| `uuid`                  | string (UUID) |                                           |
| `movement_type`         | string        | `in`, `out`, `return`, `adjustment`       |
| `quantity`              | integer       |                                           |
| `movement_date`         | ISO 8601      |                                           |
| `notes`                 | string / null |                                           |
| `product`               | object        | `{ id, name, sku_code }`                  |
| `warehouse_document_id` | integer / null| Source warehouse document                 |
| `sale_id`               | integer / null| Source sale                               |
| `client`                | object / null | `{ id, shop_name }`                       |
| `user`                  | object / null | `{ id, name }`                            |
| `created_at`            | ISO 8601      |                                           |

---

## 7. Common Patterns

### Pagination

All list endpoints return a standard Laravel paginator envelope:

```json
{
  "data": [ /* ... */ ],
  "links": {
    "first": "https://<host>/api/v1/products?page=1",
    "last":  "https://<host>/api/v1/products?page=5",
    "prev":  null,
    "next":  "https://<host>/api/v1/products?page=2"
  },
  "meta": {
    "current_page": 1,
    "from": 1,
    "last_page": 5,
    "per_page": 20,
    "to": 20,
    "total": 98
  }
}
```

### Offline Sync / Idempotency

Clients that operate offline should generate a UUID v4 (`external_uuid`) locally before submitting. On sync, if the server already has a record with that `external_uuid`, it returns the existing resource with `200` instead of creating a duplicate. This applies to **Clients**, **Warehouse Documents**, and **Sales**.

### Soft Deletes

Products are soft-deleted (archived) on `DELETE`. They remain in the database and continue to appear in stock movement history. Pass `status=active` to exclude archived products from listings.

---

## 8. Error Responses

### 401 Unauthenticated

```json
{ "message": "Unauthenticated." }
```

### 403 Forbidden

```json
{ "message": "This action is unauthorized." }
```

### 404 Not Found

```json
{ "message": "No query results for model [App\\Models\\Product] 99." }
```

### 422 Unprocessable Entity (Validation)

```json
{
  "message": "The sku_code has already been taken.",
  "errors": {
    "sku_code": ["The sku_code has already been taken."],
    "items.0.quantity": ["The items.0.quantity field must be at least 1."]
  }
}
```

### 500 Server Error

```json
{ "message": "Server Error" }
```

---

*Generated for TGC Carpets ERP — Backend v1 · Laravel Sanctum Auth · March 2026*

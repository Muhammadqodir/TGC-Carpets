# TGC Carpets — REST API Documentation

**Base URL:** `https://<host>/api/v1`  
**Authentication:** Laravel Sanctum — Bearer token  
**Content-Type:** `application/json` (unless noted otherwise)

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [Products](#2-products)
3. [Colors](#3-colors)
4. [Product Colors](#4-product-colors)
5. [Product Types](#5-product-types)
6. [Product Qualities](#6-product-qualities)
7. [Product Sizes](#7-product-sizes)
8. [Clients](#8-clients)
9. [Employees](#9-employees)
10. [Product Variants](#10-product-variants)
11. [Warehouse Documents](#11-warehouse-documents)
12. [Orders](#12-orders)
13. [Sales](#13-sales)
14. [Stock](#14-stock)
15. [Machines](#15-machines)
16. [Production Batches](#16-production-batches)
17. [Dashboard](#17-dashboard)
18. [Common Patterns](#18-common-patterns)
19. [Error Responses](#19-error-responses)

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

### 1.4 Change Password

Change the authenticated user's own password. **Requires authentication.**

```
POST /auth/change-password
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field                          | Type   | Required | Validation                       |
|--------------------------------|--------|----------|----------------------------------|
| `current_password`             | string | Yes      | Must match current password      |
| `new_password`                 | string | Yes      | min:8                            |
| `new_password_confirmation`    | string | Yes      | Must match `new_password`        |

**Response `200 OK`**

```json
{ "message": "Parol muvaffaqiyatli o'zgartirildi." }
```

**Response `422 Unprocessable Entity`** — If `current_password` does not match.

```json
{ "message": "Joriy parol noto'g'ri." }
```

---

## 2. Products

All endpoints require authentication.

### Product Object

| Field                | Type            | Description                                          |
|----------------------|-----------------|------------------------------------------------------|
| `id`                 | integer         | Internal ID                                          |
| `uuid`               | string (UUID)   | Stable public identifier                             |
| `name`               | string          | Product name                                         |
| `product_type_id`    | integer / null  | FK to product types                                  |
| `product_type`       | object / null   | `{ id, type }` — loaded relation                    |
| `product_quality_id` | integer / null  | FK to product qualities                              |
| `product_quality`    | object / null   | `{ id, quality_name, density }` — loaded relation   |
| `unit`               | string          | Unit of measure (e.g. `piece`, `m2`)                 |
| `status`             | string          | `active` or `archived`                               |
| `product_colors`     | array           | Color+image entries (see Product Color Object below) |
| `stock`              | integer         | Calculated stock — **only in `GET /products/{id}`**  |
| `created_at`         | ISO 8601        |                                                      |
| `updated_at`         | ISO 8601        |                                                      |

**Product Color Object** (inside `product_colors`):

| Field       | Type          | Description                            |
|-------------|---------------|----------------------------------------|
| `id`        | integer       | Product-color entry ID                 |
| `color`     | object        | `{ id, name }` — color reference       |
| `image_url` | string / null | Public URL of the color-specific image |

---

### 2.1 List Products

```
GET /products
Authorization: Bearer <token>
```

> `stock` is **not** calculated on the list endpoint for performance. Use `GET /products/{id}` to get the stock for a single product.

**Query Parameters**

| Parameter            | Type    | Description                              |
|----------------------|---------|------------------------------------------|
| `search`             | string  | Partial match on `name`                  |
| `name`               | string  | Partial match on name                    |
| `product_type_id`    | integer | Filter by product type                   |
| `product_quality_id` | integer | Filter by product quality                |
| `status`             | string  | `active` or `archived`                   |
| `per_page`           | integer | Results per page (default: `20`)         |
| `page`               | integer | Page number (default: `1`)               |

**Response `200 OK`**

```json
{
  "data": [
    {
      "id": 1,
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Persian Classic",
      "product_type_id": 2,
      "product_type": { "id": 2, "type": "Runner" },
      "product_quality_id": 1,
      "product_quality": { "id": 1, "quality_name": "Premium", "density": 500 },
      "unit": "piece",
      "status": "active",
      "product_colors": [
        {
          "id": 5,
          "color": { "id": 3, "name": "Red" },
          "image_url": "https://<host>/storage/products/abc.jpg"
        }
      ],
      "stock": 0,
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
Content-Type: application/json
```

**Request Body**

| Field                | Type    | Required | Validation                                    |
|----------------------|---------|----------|-----------------------------------------------|
| `name`               | string  | Yes      | max:255                                       |
| `product_type_id`    | integer | No       | must exist in `product_types`                 |
| `product_quality_id` | integer | No       | must exist in `product_qualities`             |
| `unit`               | string  | Yes      | e.g. `piece`, `m2`                            |
| `status`             | string  | No       | `active` or `archived` (default: `active`)    |

> Colors and images are managed separately via the **Product Colors** endpoints.

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

> This endpoint calculates and returns the live `stock` value for the product.

**Response `200 OK`**

```json
{
  "data": { /* Product Object with stock calculated */ }
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
PUT /products/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

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

## 3. Colors

All endpoints require authentication.

### Color Object

| Field  | Type    | Description  |
|--------|---------|--------------|
| `id`   | integer | Internal ID  |
| `name` | string  | Color name   |

---

### 3.1 List Colors

```
GET /colors
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter | Type   | Description           |
|-----------|--------|-----------------------|
| `search`  | string | Partial match on name |

**Response `200 OK`**

```json
{
  "data": [
    { "id": 1, "name": "Red" },
    { "id": 2, "name": "Blue" }
  ]
}
```

---

### 3.2 Create Color

```
POST /colors
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field  | Type   | Required | Validation           |
|--------|--------|----------|----------------------|
| `name` | string | Yes      | max:100, unique      |

**Response `201 Created`**

```json
{
  "data": { "id": 3, "name": "Green" }
}
```

---

## 4. Product Colors

A Product Color entry links a product to a color and optionally attaches a color-specific product image. All endpoints require authentication.

### Product Color Object

| Field        | Type          | Description                             |
|--------------|---------------|-----------------------------------------|
| `id`         | integer       | Internal ID                             |
| `product`    | object        | `{ id, name }` — parent product         |
| `color`      | object        | `{ id, name }` — associated color       |
| `image_url`  | string / null | Public URL of the color-specific image  |
| `created_at` | ISO 8601      |                                         |

---

### 4.1 List Product Colors

```
GET /product-colors
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter    | Type    | Description              |
|--------------|---------|--------------------------|
| `product_id` | integer | Filter by product        |
| `color_id`   | integer | Filter by color          |
| `per_page`   | integer | Default: `50`            |
| `page`       | integer | Default: `1`             |

**Response `200 OK`** — Paginated list of Product Color Objects.

---

### 4.2 Create Product Color

```
POST /product-colors
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Request Body**

| Field        | Type    | Required | Validation                              |
|--------------|---------|----------|-----------------------------------------|
| `product_id` | integer | Yes      | must exist in `products`                |
| `color_id`   | integer | Yes      | must exist in `colors`                  |
| `image`      | file    | Yes      | jpg, jpeg, png, webp — max 4 MB         |

**Response `201 Created`**

```json
{
  "data": {
    "id": 5,
    "product": { "id": 1, "name": "Persian Classic" },
    "color": { "id": 3, "name": "Red" },
    "image_url": "https://<host>/storage/products/abc.jpg"
  }
}
```

---

### 4.3 Update Product Color

Replace the color or image on an existing product-color entry.

```
POST /product-colors/{id}?_method=PUT
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Request Body**

| Field      | Type    | Required | Validation                              |
|------------|---------|----------|-----------------------------------------|
| `color_id` | integer | No       | must exist in `colors`                  |
| `image`    | file    | No       | jpg, jpeg, png, webp — max 4 MB         |

**Response `200 OK`**

```json
{
  "data": { /* updated Product Color Object */ }
}
```

---

### 4.4 Delete Product Color

```
DELETE /product-colors/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Product color deleted." }
```

---

## 5. Product Types

Read-only reference list. All endpoints require authentication.

### Product Type Object

| Field  | Type    | Description       |
|--------|---------|-------------------|
| `id`   | integer | Internal ID       |
| `type` | string  | Product type name |

---

### 5.1 List Product Types

```
GET /product-types
Authorization: Bearer <token>
```

Returns all product types (no pagination — small reference list).

**Response `200 OK`**

```json
{
  "data": [
    { "id": 1, "type": "Classic" },
    { "id": 2, "type": "Runner" },
    { "id": 3, "type": "Shaggy" }
  ]
}
```

---

## 6. Product Qualities

All endpoints require authentication.

### Product Quality Object

| Field          | Type           | Description              |
|----------------|----------------|--------------------------|
| `id`           | integer        | Internal ID              |
| `quality_name` | string         | Quality label            |
| `density`      | integer / null | Density value (optional) |

---

### 6.1 List Product Qualities

```
GET /product-qualities
Authorization: Bearer <token>
```

Returns all product qualities (no pagination).

**Response `200 OK`**

```json
{
  "data": [
    { "id": 1, "quality_name": "Premium", "density": 800 },
    { "id": 2, "quality_name": "Standard", "density": 500 }
  ]
}
```

---

### 6.2 Create Product Quality

```
POST /product-qualities
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field          | Type    | Required | Validation         |
|----------------|---------|----------|--------------------|
| `quality_name` | string  | Yes      | max:100, unique    |
| `density`      | integer | No       | min:1              |

**Response `201 Created`**

```json
{
  "data": { "id": 3, "quality_name": "Economy", "density": null }
}
```

---

### 6.3 Update Product Quality

```
PUT /product-qualities/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** — All fields optional:

| Field          | Type    | Validation                                        |
|----------------|---------|---------------------------------------------------|
| `quality_name` | string  | max:100, unique (excluding current record)        |
| `density`      | integer | min:1, nullable                                   |

**Response `200 OK`**

```json
{
  "data": { /* updated Product Quality Object */ }
}
```

---

### 6.4 Delete Product Quality

```
DELETE /product-qualities/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Product quality deleted successfully." }
```

---

## 7. Product Sizes

All endpoints require authentication.

### Product Size Object

| Field             | Type           | Description                             |
|-------------------|----------------|-----------------------------------------|
| `id`              | integer        | Internal ID                             |
| `length`          | integer        | Length in cm                            |
| `width`           | integer        | Width in cm                             |
| `product_type_id` | integer        | FK to product types                     |
| `product_type`    | object / null  | `{ id, type }` — loaded relation        |
| `created_at`      | ISO 8601       |                                         |
| `updated_at`      | ISO 8601       |                                         |

---

### 7.1 List Product Sizes

```
GET /product-sizes
Authorization: Bearer <token>
```

Returns all sizes (no pagination), ordered by `length` then `width`.

**Query Parameters**

| Parameter         | Type    | Description               |
|-------------------|---------|---------------------------|
| `product_type_id` | integer | Filter by product type    |

**Response `200 OK`**

```json
{
  "data": [
    {
      "id": 1,
      "length": 100,
      "width": 150,
      "product_type_id": 1,
      "product_type": { "id": 1, "type": "Classic" },
      "created_at": "2025-01-01T00:00:00.000000Z",
      "updated_at": "2025-01-01T00:00:00.000000Z"
    }
  ]
}
```

---

### 7.2 Create Product Size

```
POST /product-sizes
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field             | Type    | Required | Validation                                                                |
|-------------------|---------|----------|---------------------------------------------------------------------------|
| `length`          | integer | Yes      | min:1                                                                     |
| `width`           | integer | Yes      | min:1                                                                     |
| `product_type_id` | integer | Yes      | must exist in `product_types`; combination of `length+width+product_type_id` must be unique |

**Response `201 Created`**

```json
{
  "data": { /* Product Size Object */ }
}
```

---

### 7.3 Get Product Size

```
GET /product-sizes/{id}
Authorization: Bearer <token>
```

**Response `200 OK`** — Product Size Object.

---

### 7.4 Update Product Size

```
PUT /product-sizes/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** — All fields optional (same constraints as Create).

**Response `200 OK`** — Updated Product Size Object.

---

### 7.5 Delete Product Size

```
DELETE /product-sizes/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Product size deleted successfully." }
```

---

## 8. Clients

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

### 5.1 List Clients

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

### 5.2 Create Client

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

### 5.3 Get Client

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

### 5.4 Update Client

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

### 5.5 Delete Client

```
DELETE /clients/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Client deleted successfully." }
```

---

## 9. Employees

All endpoints require authentication.

### Employee Object

| Field        | Type           | Description                             |
|--------------|----------------|-----------------------------------------|
| `id`         | integer        | Internal ID                             |
| `name`       | string         | Full name                               |
| `email`      | string         | Email address                           |
| `phone`      | string / null  | Phone number                            |
| `role`       | string         | `admin`, `warehouse`, or `seller`       |
| `created_at` | ISO 8601       |                                         |
| `updated_at` | ISO 8601       |                                         |

---

### 9.1 List Employees

```
GET /employees
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter  | Type    | Description                                       |
|------------|---------|---------------------------------------------------|
| `search`   | string  | Partial match on `name`, `email`, or `phone`      |
| `role`     | string  | `admin`, `warehouse`, or `seller`                 |
| `per_page` | integer | Default: `20`                                     |
| `page`     | integer | Default: `1`                                      |

**Response `200 OK`** — Paginated list of Employee Objects.

---

### 9.2 Create Employee

```
POST /employees
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field      | Type   | Required | Validation                              |
|------------|--------|----------|-----------------------------------------|
| `name`     | string | Yes      | max:255                                 |
| `email`    | string | Yes      | unique, valid email                     |
| `phone`    | string | No       | max:20                                  |
| `password` | string | Yes      | min:8                                   |
| `role`     | string | Yes      | `admin`, `warehouse`, or `seller`       |

**Response `201 Created`**

```json
{
  "data": { /* Employee Object */ }
}
```

---

### 9.3 Get Employee

```
GET /employees/{id}
Authorization: Bearer <token>
```

**Response `200 OK`** — Employee Object.

---

### 9.4 Update Employee

```
PUT /employees/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

All fields optional. `password` if provided must be min:8; omit to leave password unchanged.

**Response `200 OK`** — Updated Employee Object.

---

### 9.5 Delete Employee

```
DELETE /employees/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Employee deleted successfully." }
```

---

## 10. Product Variants

A Product Variant ties a **Product Color** to a **Product Size**, generating a unique SKU code and barcode. All endpoints require authentication.

### Product Variant Object

| Field           | Type           | Description                                             |
|-----------------|----------------|---------------------------------------------------------|
| `id`            | integer        | Internal ID                                             |
| `barcode_value` | string         | Barcode string (for label printing and scanning)        |
| `sku_code`      | string         | Human-readable SKU                                      |
| `product_color` | object / null  | `{ id, image, color: { id, name }, product: { id, name, unit, status, product_type: { id, type }, product_quality: { id, quality_name } } }` |
| `product_size`  | object / null  | `{ id, length, width }`                                 |
| `created_at`    | ISO 8601       |                                                         |

> **Note:** `product_color.image` is the raw storage path. Construct the full URL as `<host>/storage/<image>`.

---

### 10.1 List Product Variants

```
GET /product-variants
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter          | Type    | Description                            |
|--------------------|---------|----------------------------------------|
| `product_color_id` | integer | Filter by product-color entry          |
| `barcode`          | string  | Exact match on barcode value           |
| `per_page`         | integer | Default: `50`                          |
| `page`             | integer | Default: `1`                           |

**Response `200 OK`** — Paginated list of Product Variant Objects.

---

### 10.2 Find Variant by Barcode

Resolve a single variant by scanning its barcode label.

```
GET /product-variants/barcode/{barcode}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{
  "data": {
    "id": 12,
    "barcode_value": "TGC-001-RED-100x150",
    "sku_code": "TGC-001-RED-100x150",
    "product_color": {
      "id": 5,
      "image": "products/abc.jpg",
      "color": { "id": 3, "name": "Red" },
      "product": {
        "id": 1,
        "name": "Persian Classic",
        "unit": "piece",
        "status": "active",
        "product_type": { "id": 2, "type": "Runner" },
        "product_quality": { "id": 1, "quality_name": "Premium" }
      }
    },
    "product_size": { "id": 4, "length": 100, "width": 150 },
    "created_at": "2025-01-15T08:00:00.000000Z"
  }
}
```

**Response `404 Not Found`**

```json
{ "message": "No query results for model [App\\Models\\ProductVariant]." }
```

---

## 11. Warehouse Documents

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

### 6.1 List Warehouse Documents

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

### 6.2 Create Warehouse Document

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

### 6.3 Get Warehouse Document

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

### 6.4 Update Warehouse Document

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

### 6.5 Delete Warehouse Document

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

### 6.6 Upload Photo

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

### 6.7 Delete Photo

```
DELETE /warehouse-documents/{id}/photos/{photoId}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Photo deleted." }
```

---

## 12. Orders

An Order records a client's request for specific product variants (color + size combinations). Orders drive production planning. All endpoints require authentication.

### Order Statuses

| Value           | Meaning                                      |
|-----------------|----------------------------------------------|
| `pending`       | Order received, not yet in production        |
| `on_production` | Assigned to one or more production batches   |
| `done`          | All items produced and delivered             |
| `canceled`      | Order cancelled                              |

### Order Object

| Field           | Type           | Description                                     |
|-----------------|----------------|-------------------------------------------------|
| `id`            | integer        | Internal ID                                     |
| `uuid`          | string (UUID)  | Stable public identifier                        |
| `external_uuid` | string / null  | Client-generated UUID for offline sync          |
| `status`        | string         | See Order Statuses above                        |
| `order_date`    | date           | `YYYY-MM-DD`                                    |
| `notes`         | string / null  |                                                 |
| `user`          | object / null  | `{ id, name }` — who created the order          |
| `client`        | object / null  | `{ id, shop_name, phone, region }`              |
| `items`         | array          | Order line items (see below)                    |
| `created_at`    | ISO 8601       |                                                 |
| `updated_at`    | ISO 8601       |                                                 |

**Order Item Object**

| Field      | Type    | Description                                                              |
|------------|---------|--------------------------------------------------------------------------|
| `id`       | integer |                                                                          |
| `quantity` | integer | Ordered quantity                                                         |
| `variant`  | object  | `{ id, barcode_value, sku_code, product_color: {...}, product_size: {...} }` |

---

### 12.1 List Orders

```
GET /orders
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter   | Type    | Description                                      |
|-------------|---------|--------------------------------------------------|
| `status`    | string  | `pending`, `on_production`, `done`, `canceled`   |
| `client_id` | integer | Filter by client                                 |
| `user_id`   | integer | Filter by creator                                |
| `date_from` | date    | `YYYY-MM-DD`                                     |
| `date_to`   | date    | `YYYY-MM-DD`                                     |
| `per_page`  | integer | Default: `20`                                    |
| `page`      | integer | Default: `1`                                     |

**Response `200 OK`** — Paginated list of Order Objects.

---

### 12.2 Create Order

Idempotent — if `external_uuid` already exists, the existing order is returned (`200`).

```
POST /orders
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field                       | Type    | Required | Description                                |
|-----------------------------|---------|----------|--------------------------------------------|
| `client_id`                 | integer | Yes      | Must exist in `clients` table              |
| `order_date`                | date    | Yes      | `YYYY-MM-DD`                               |
| `status`                    | string  | No       | Default: `pending`                         |
| `notes`                     | string  | No       | max:1000                                   |
| `external_uuid`             | string  | No       | For offline sync deduplication             |
| `items`                     | array   | Yes      | min 1 item                                 |
| `items[].product_color_id`  | integer | Yes      | Must exist in `product_colors` table       |
| `items[].product_size_id`   | integer | No       | Must exist in `product_sizes` table        |
| `items[].quantity`          | integer | Yes      | min:1                                      |

```json
{
  "client_id": 3,
  "order_date": "2026-04-10",
  "items": [
    { "product_color_id": 5, "product_size_id": 4, "quantity": 10 },
    { "product_color_id": 7, "product_size_id": 2, "quantity": 5 }
  ]
}
```

**Response `201 Created` / `200 OK` (existing)**

```json
{
  "data": { /* Order Object */ }
}
```

---

### 12.3 Get Order

```
GET /orders/{id}
Authorization: Bearer <token>
```

**Response `200 OK`** — Order Object with all relations loaded.

---

### 12.4 Update Order

Supplying `items` replaces all line items.

```
PUT /orders/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** — All fields optional:

| Field                       | Type    | Description                                     |
|-----------------------------|---------|------------------------------------------------ |
| `client_id`                 | integer | nullable                                        |
| `status`                    | string  | `pending`, `on_production`, `done`, `canceled`  |
| `order_date`                | date    | `YYYY-MM-DD`                                    |
| `notes`                     | string  | nullable, max:1000                              |
| `items`                     | array   | Replaces all items when provided                |
| `items[].product_color_id`  | integer |                                                 |
| `items[].product_size_id`   | integer | nullable                                        |
| `items[].quantity`          | integer | min:1                                           |

**Response `200 OK`** — Updated Order Object.

---

### 12.5 Delete Order

```
DELETE /orders/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Order deleted." }
```

---

## 13. Sales

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

### 7.1 List Sales

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

### 7.2 Create Sale

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

### 7.3 Get Sale

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

### 7.4 Update Sale

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

### 7.5 Delete Sale

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

## 14. Stock

Read-only endpoints available to all authenticated roles.

### 8.1 Current Stock Levels

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

### 8.2 Stock Movement History

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

## 15. Machines

Machines are the looms used in production batches. All endpoints require authentication.

### Machine Object

| Field        | Type           | Description                |
|--------------|----------------|----------------------------|
| `id`         | integer        | Internal ID                |
| `name`       | string         | Machine name               |
| `model_name` | string / null  | Model / serial identifier  |
| `created_at` | ISO 8601       |                            |
| `updated_at` | ISO 8601       |                            |

---

### 15.1 List Machines

```
GET /machines
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter  | Type    | Description              |
|------------|---------|--------------------------|
| `search`   | string  | Partial match on `name`  |
| `per_page` | integer | Default: `50`            |
| `page`     | integer | Default: `1`             |

**Response `200 OK`** — Paginated list of Machine Objects.

---

### 15.2 Create Machine

```
POST /machines
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field        | Type   | Required | Validation |
|--------------|--------|----------|------------|
| `name`       | string | Yes      | max:255    |
| `model_name` | string | No       | max:255    |

**Response `201 Created`**

```json
{
  "data": {
    "id": 1,
    "name": "Loom A",
    "model_name": "XL-2000",
    "created_at": "2026-01-01T00:00:00.000000Z",
    "updated_at": "2026-01-01T00:00:00.000000Z"
  }
}
```

---

### 15.3 Get Machine

```
GET /machines/{id}
Authorization: Bearer <token>
```

**Response `200 OK`** — Machine Object.

---

### 15.4 Update Machine

```
PUT /machines/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** — All fields optional (same constraints as Create).

**Response `200 OK`** — Updated Machine Object.

---

### 15.5 Delete Machine

```
DELETE /machines/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Machine deleted." }
```

---

## 16. Production Batches

A Production Batch groups one or more production items to be woven on a specific machine. Batches optionally link to Order Items. All endpoints require authentication.

### Batch Types

| Value        | Meaning                                     |
|--------------|---------------------------------------------|
| `by_order`   | Batch entirely driven by client orders      |
| `for_stock`  | Batch for warehouse stock (no order link)   |
| `mixed`      | Mix of order-driven and stock items         |

### Batch Statuses

| Value         | Meaning                       | Transitions from     |
|---------------|-------------------------------|----------------------|
| `planned`     | Scheduled, not yet started    | — (initial)          |
| `in_progress` | Currently being produced      | `planned`            |
| `completed`   | Production finished           | `in_progress`        |
| `cancelled`   | Cancelled before completion   | `planned`, `in_progress` |

### Production Batch Object

| Field                | Type              | Description                                           |
|----------------------|-------------------|-------------------------------------------------------|
| `id`                 | integer           | Internal ID                                           |
| `batch_title`        | string            | Descriptive title                                     |
| `planned_datetime`   | ISO 8601 / null   | When production is planned to start                   |
| `started_datetime`   | ISO 8601 / null   | When production actually started                      |
| `completed_datetime` | ISO 8601 / null   | When production completed                             |
| `type`               | string            | `by_order`, `for_stock`, `mixed`                      |
| `status`             | string            | `planned`, `in_progress`, `completed`, `cancelled`    |
| `notes`              | string / null     |                                                       |
| `machine`            | object / null     | `{ id, name, model_name }`                            |
| `creator`            | object / null     | `{ id, name }`                                        |
| `items`              | array             | Batch items (loaded on `show` only)                   |
| `items_count`        | integer           | Count of items (on list endpoint)                     |
| `created_at`         | ISO 8601          |                                                       |
| `updated_at`         | ISO 8601          |                                                       |

**Production Batch Item Object**

| Field                          | Type           | Description                                                                   |
|--------------------------------|----------------|-------------------------------------------------------------------------------|
| `id`                           | integer        |                                                                               |
| `source_type`                  | string         | `order_item`, `stock_request`, `manual`                                       |
| `planned_quantity`             | integer        | Planned output                                                                |
| `produced_quantity`            | integer / null | Actual produced quantity                                                      |
| `defect_quantity`              | integer / null | Defect / reject count                                                         |
| `warehouse_received_quantity`  | integer / null | Quantity received into warehouse                                              |
| `notes`                        | string / null  |                                                                               |
| `source_order_item`            | object / null  | `{ id, quantity, order: { id, uuid, client: { id, shop_name } } }`            |
| `variant`                      | object / null  | Product Variant object (with nested `product_color`, `product_size`)          |
| `created_at`                   | ISO 8601       |                                                                               |
| `updated_at`                   | ISO 8601       |                                                                               |

---

### 16.1 List Production Batches

```
GET /production-batches
Authorization: Bearer <token>
```

**Query Parameters**

| Parameter    | Type    | Description                                          |
|--------------|---------|------------------------------------------------------|
| `status`     | string  | `planned`, `in_progress`, `completed`, `cancelled`   |
| `type`       | string  | `by_order`, `for_stock`, `mixed`                     |
| `machine_id` | integer | Filter by machine                                    |
| `date_from`  | date    | Filter `planned_datetime >= YYYY-MM-DD`              |
| `date_to`    | date    | Filter `planned_datetime <= YYYY-MM-DD`              |
| `per_page`   | integer | Default: `20`                                        |
| `page`       | integer | Default: `1`                                         |

**Response `200 OK`** — Paginated list of Production Batch Objects (with `items_count`, without `items` array).

---

### 16.2 Create Production Batch

```
POST /production-batches
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body**

| Field                            | Type     | Required | Description                                          |
|----------------------------------|----------|----------|------------------------------------------------------|
| `batch_title`                    | string   | Yes      | max:255                                              |
| `machine_id`                     | integer  | Yes      | Must exist in `machines` table                       |
| `planned_datetime`               | datetime | No       | ISO 8601 or `YYYY-MM-DD`                             |
| `type`                           | string   | No       | Default: `by_order`                                  |
| `notes`                          | string   | No       | max:2000                                             |
| `items`                          | array    | No       | Initial batch items                                  |
| `items[].source_type`            | string   | No       | `order_item`, `stock_request`, `manual`              |
| `items[].source_order_item_id`   | integer  | No       | Must exist in `order_items`                          |
| `items[].product_variant_id`     | integer  | No       | Must exist in `product_variants`                     |
| `items[].product_color_id`       | integer  | No       | Must exist in `product_colors`                       |
| `items[].product_size_id`        | integer  | No       | Must exist in `product_sizes`                        |
| `items[].planned_quantity`       | integer  | Yes*     | min:1 (*required when `items` is present)            |
| `items[].notes`                  | string   | No       | max:1000                                             |

**Response `201 Created`**

```json
{
  "data": { /* Production Batch Object */ }
}
```

---

### 16.3 Get Production Batch

```
GET /production-batches/{id}
Authorization: Bearer <token>
```

Returns the full batch with all items and their nested relations.

**Response `200 OK`** — Full Production Batch Object.

---

### 16.4 Update Production Batch

Supplying `items` replaces all existing batch items.

```
PUT /production-batches/{id}
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** — All fields optional (same as Create).

**Response `200 OK`** — Updated Production Batch Object.

---

### 16.5 Delete Production Batch

```
DELETE /production-batches/{id}
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{ "message": "Production batch deleted." }
```

---

### 16.6 Start Batch

Transitions batch from `planned` → `in_progress`. Records `started_datetime`.

```
POST /production-batches/{id}/start
Authorization: Bearer <token>
```

**Response `200 OK`** — Updated Production Batch Object.

**Response `422 Unprocessable Entity`** — If batch is not in `planned` status.

```json
{ "message": "Batch can only be started from planned status." }
```

---

### 16.7 Complete Batch

Transitions batch from `in_progress` → `completed`. Records `completed_datetime`.

```
POST /production-batches/{id}/complete
Authorization: Bearer <token>
```

**Response `200 OK`** — Updated Production Batch Object.

**Response `422 Unprocessable Entity`** — If batch is not in `in_progress` status.

```json
{ "message": "Batch can only be completed from in_progress status." }
```

---

### 16.8 Cancel Batch

Cancels a batch that is `planned` or `in_progress`. Completed batches cannot be cancelled.

```
POST /production-batches/{id}/cancel
Authorization: Bearer <token>
```

**Response `200 OK`** — Updated Production Batch Object.

**Response `422 Unprocessable Entity`** — If batch is already `completed`.

```json
{ "message": "Completed batches cannot be cancelled." }
```

---

### 16.9 Update Batch Item

Update produced and defect quantities for a single item during or after production.

```
PATCH /production-batches/{id}/items/{itemId}
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body** — All fields optional:

| Field                | Type    | Validation          |
|----------------------|---------|---------------------|
| `produced_quantity`  | integer | min:0               |
| `defect_quantity`    | integer | min:0               |
| `notes`              | string  | nullable, max:1000  |

**Response `200 OK`**

```json
{
  "data": { /* Production Batch Item Object */ }
}
```

**Response `404 Not Found`** — If the item does not belong to the specified batch.

---

### 16.10 Available Order Items for Production

Returns all order items from `pending` or `on_production` orders that still have a remaining quantity not yet covered by non-cancelled batches. Items with `remaining_quantity = 0` are excluded.

```
GET /production-batches-order-items
Authorization: Bearer <token>
```

**Response `200 OK`**

```json
{
  "data": [
    {
      "order_item_id": 42,
      "order_id": 10,
      "order_number": 10,
      "client_shop_name": "Carpet Palace",
      "ordered_quantity": 20,
      "planned_quantity": 8,
      "remaining_quantity": 12,
      "variant": {
        "id": 15,
        "barcode_value": "TGC-001-RED-100x150",
        "sku_code": "TGC-001-RED-100x150",
        "product_color": {
          "id": 5,
          "image_url": "https://<host>/storage/products/abc.jpg",
          "color": { "id": 3, "name": "Red" },
          "product": {
            "id": 1,
            "name": "Persian Classic",
            "product_type": { "id": 2, "type": "Runner" },
            "quality_name": "Premium"
          }
        },
        "product_size": { "id": 4, "length": 100, "width": 150 }
      }
    }
  ]
}
```

---

## 17. Dashboard

Aggregated business statistics for a given date range. All endpoints require authentication.

---

### 17.1 Dashboard Statistics

```
GET /dashboard/stats
Authorization: Bearer <token>
```

Defaults to the current calendar month when no date range is provided.

**Query Parameters**

| Parameter | Type | Description                                                      |
|-----------|------|------------------------------------------------------------------|
| `from`    | date | `YYYY-MM-DD` — start of range (default: start of current month) |
| `to`      | date | `YYYY-MM-DD` — end of range (default: end of current month)     |

**Response `200 OK`**

```json
{
  "data": {
    "production_quantity": 320,
    "warehouse_stock": 1450,
    "sales_quantity": 58,
    "sales_amount": 12400.00,
    "date_from": "2026-04-01",
    "date_to": "2026-04-30"
  }
}
```

**Response Fields**

| Field                 | Type    | Description                                                              |
|-----------------------|---------|--------------------------------------------------------------------------|
| `production_quantity` | integer | Total quantity from `in` warehouse documents in the date range           |
| `warehouse_stock`     | integer | Current net stock across all products (real-time, not date-filtered)     |
| `sales_quantity`      | integer | Total items sold in the date range                                       |
| `sales_amount`        | float   | Total revenue from sales in the date range                               |
| `date_from`           | string  | Applied start date                                                       |
| `date_to`             | string  | Applied end date                                                         |

---

## 18. Common Patterns

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

## 19. Error Responses

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

*Generated for TGC Carpets ERP — Backend v1 · Laravel Sanctum Auth · April 2026 · Sections 1–19*

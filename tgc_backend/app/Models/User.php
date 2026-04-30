<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    const ROLE_ADMIN                = 'admin';
    const ROLE_WAREHOUSE_MANAGER    = 'warehouse_manager';
    const ROLE_SALES_MANAGER        = 'sales_manager';
    const ROLE_RAW_WAREHOUSE_MANAGER = 'raw_warehouse_manager';
    const ROLE_PRODUCT_MANAGER      = 'product_manager';
    const ROLE_MACHINE_MANAGER      = 'machine_manager';
    const ROLE_PRODUCTION_MANAGER   = 'production_manager';
    const ROLE_ORDER_MANAGER        = 'order_manager';
    const ROLE_LABEL_MANAGER        = 'label_manager';

    const ROLES = [
        self::ROLE_ADMIN,
        self::ROLE_WAREHOUSE_MANAGER,
        self::ROLE_SALES_MANAGER,
        self::ROLE_RAW_WAREHOUSE_MANAGER,
        self::ROLE_PRODUCT_MANAGER,
        self::ROLE_MACHINE_MANAGER,
        self::ROLE_PRODUCTION_MANAGER,
        self::ROLE_ORDER_MANAGER,
        self::ROLE_LABEL_MANAGER,
    ];

    protected $fillable = [
        'name',
        'email',
        'phone',
        'password',
        'role',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password'          => 'hashed',
        ];
    }

    // ── Role helpers ──────────────────────────────────────────────────────────

    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    public function isWarehouseManager(): bool
    {
        return $this->role === self::ROLE_WAREHOUSE_MANAGER;
    }

    public function isSalesManager(): bool
    {
        return $this->role === self::ROLE_SALES_MANAGER;
    }

    public function isRawWarehouseManager(): bool
    {
        return $this->role === self::ROLE_RAW_WAREHOUSE_MANAGER;
    }

    public function isProductManager(): bool
    {
        return $this->role === self::ROLE_PRODUCT_MANAGER;
    }

    public function isMachineManager(): bool
    {
        return $this->role === self::ROLE_MACHINE_MANAGER;
    }

    public function isProductionManager(): bool
    {
        return $this->role === self::ROLE_PRODUCTION_MANAGER;
    }

    public function isOrderManager(): bool
    {
        return $this->role === self::ROLE_ORDER_MANAGER;
    }

    public function isLabelManager(): bool
    {
        return $this->role === self::ROLE_LABEL_MANAGER;
    }

    // Legacy helpers (for backward compatibility)
    public function isWarehouse(): bool
    {
        return $this->isWarehouseManager();
    }

    public function isSeller(): bool
    {
        return $this->isSalesManager();
    }

    // ── Relationships ─────────────────────────────────────────────────────────

    public function warehouseDocuments(): HasMany
    {
        return $this->hasMany(WarehouseDocument::class);
    }

    public function stockMovements(): HasMany
    {
        return $this->hasMany(StockMovement::class);
    }
}

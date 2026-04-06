<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ProductTypeResource;
use App\Models\ProductType;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ProductTypeController extends Controller
{
    public function index(): AnonymousResourceCollection
    {
        return ProductTypeResource::collection(ProductType::orderBy('type')->get());
    }
}

<?php

namespace App\Http\Requests\Analytics;

use Illuminate\Foundation\Http\FormRequest;

class TopProductsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'period_from' => ['nullable', 'date', 'before_or_equal:period_to'],
            'period_to'   => ['nullable', 'date', 'after_or_equal:period_from'],
            'limit'       => ['nullable', 'integer', 'in:10,20,30,40,50'],
            'type_id'     => ['nullable', 'integer', 'exists:product_types,id'],
            'quality_id'  => ['nullable', 'integer', 'exists:product_qualities,id'],
            'size_id'     => ['nullable', 'integer', 'exists:product_sizes,id'],
            'color_id'    => ['nullable', 'integer', 'exists:colors,id'],
            'edge_id'     => ['nullable', 'integer', 'exists:product_edges,id'],
        ];
    }

    public function periodFrom(): string
    {
        return $this->input('period_from', now()->subDays(30)->toDateString());
    }

    public function periodTo(): string
    {
        return $this->input('period_to', now()->toDateString());
    }

    public function limit(): int
    {
        return (int) $this->input('limit', 10);
    }

    public function typeId(): ?int
    {
        return $this->filled('type_id') ? (int) $this->input('type_id') : null;
    }

    public function qualityId(): ?int
    {
        return $this->filled('quality_id') ? (int) $this->input('quality_id') : null;
    }

    public function sizeId(): ?int
    {
        return $this->filled('size_id') ? (int) $this->input('size_id') : null;
    }

    public function colorId(): ?int
    {
        return $this->filled('color_id') ? (int) $this->input('color_id') : null;
    }

    public function edgeId(): ?int
    {
        return $this->filled('edge_id') ? (int) $this->input('edge_id') : null;
    }
}

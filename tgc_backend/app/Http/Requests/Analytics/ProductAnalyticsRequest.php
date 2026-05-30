<?php

namespace App\Http\Requests\Analytics;

use Illuminate\Foundation\Http\FormRequest;

class ProductAnalyticsRequest extends FormRequest
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
            'trend_by'    => ['nullable', 'string', 'in:day,week,month'],
        ];
    }

    /**
     * Return validated period boundaries with sensible defaults (last 30 days).
     */
    public function periodFrom(): string
    {
        return $this->input('period_from', now()->subDays(30)->toDateString());
    }

    public function periodTo(): string
    {
        return $this->input('period_to', now()->toDateString());
    }

    public function trendBy(): string
    {
        return $this->input('trend_by', 'day');
    }
}

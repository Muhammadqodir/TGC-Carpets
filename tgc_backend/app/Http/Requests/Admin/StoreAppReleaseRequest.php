<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\UploadedFile;
use Illuminate\Validation\Validator;

class StoreAppReleaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Authorization is handled by the auth + web_admin middleware on the route.
        return true;
    }

    public function rules(): array
    {
        return [
            'platform'    => ['required', 'in:android,windows'],
            'version'     => ['required', 'string', 'max:20', 'regex:/^\d+\.\d+\.\d+$/'],
            'build_code'  => ['required', 'integer', 'min:1'],
            'is_required' => ['sometimes', 'boolean'],
            'changelog'   => ['nullable', 'string', 'max:5000'],
            // 200 MB max; extension validated in withValidator below
            'file'        => ['required', 'file', 'max:204800'],
        ];
    }

    /**
     * Add a post-validation check that enforces the expected file extension
     * based on the selected platform.  We do this after the standard rules
     * so that we have a clean, already-validated `platform` value to work with.
     */
    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $v): void {
            /** @var UploadedFile|null $file */
            $file     = $this->file('file');
            $platform = $this->input('platform');

            if (! $file || ! $platform) {
                return;
            }

            $expected = $platform === 'android' ? 'apk' : 'exe';
            $actual   = strtolower($file->getClientOriginalExtension());

            if ($actual !== $expected) {
                $v->errors()->add(
                    'file',
                    "Fayl kengaytmasi «.{$expected}» bo'lishi kerak (yuklangan: «.{$actual}»).",
                );
            }
        });
    }

    public function messages(): array
    {
        return [
            'version.regex'    => 'Versiya formati noto\'g\'ri. Masalan: 1.2.3',
            'build_code.min'   => 'Build raqami musbat bo\'lishi kerak.',
            'file.max'         => 'Fayl hajmi 200 MB dan oshmasligi kerak.',
            'file.required'    => 'Fayl yuklash majburiy.',
        ];
    }
}

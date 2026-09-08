<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // An official price is a HISTORICAL EVENT. "Updating" one inserts a new
        // row; the newest row for a (product, unit, amount) tuple is current.
        Schema::create('official_prices', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('product_id')->constrained('products')->restrictOnDelete();
            $table->foreignId('unit_id')->constrained('units')->restrictOnDelete();
            $table->decimal('amount', 12, 3);
            $table->decimal('price', 18, 2);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('created_at')->nullable();

            $table->index(['product_id', 'unit_id', 'created_at']);
            $table->index('product_id');
        });

        DB::statement('ALTER TABLE official_prices ADD CONSTRAINT official_prices_amount_check CHECK (amount > 0)');
        DB::statement('ALTER TABLE official_prices ADD CONSTRAINT official_prices_price_check CHECK (price >= 0)');
    }

    public function down(): void
    {
        Schema::dropIfExists('official_prices');
    }
};

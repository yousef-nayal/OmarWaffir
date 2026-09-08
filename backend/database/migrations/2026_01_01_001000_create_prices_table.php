<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A market price is an EVENT, not an attribute of a product.
        // There is deliberately NO status/approval column: administrators
        // review prices by deleting incorrect ones.
        Schema::create('prices', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->foreignId('user_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('store_id')->constrained('stores')->restrictOnDelete();
            $table->foreignId('product_id')->constrained('products')->restrictOnDelete();
            $table->foreignId('unit_id')->constrained('units')->restrictOnDelete();
            $table->foreignId('brand_id')->nullable()->constrained('brands')->restrictOnDelete();
            $table->decimal('amount', 12, 3);
            $table->decimal('price', 18, 2);
            $table->timestamps();

            $table->index(['product_id', 'created_at']);
            $table->index(['store_id', 'created_at']);
            $table->index(['user_id', 'created_at']);
        });

        DB::statement('ALTER TABLE prices ADD CONSTRAINT prices_amount_check CHECK (amount > 0)');
        DB::statement('ALTER TABLE prices ADD CONSTRAINT prices_price_check CHECK (price >= 0)');
    }

    public function down(): void
    {
        Schema::dropIfExists('prices');
    }
};

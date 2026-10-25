import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { ProductsController } from './products/products.controller';
import { ProductsService } from './products/products.service';
import { CategoriesController } from './categories/categories.controller';
import { CategoriesService } from './categories/categories.service';
import { UnitsController } from './units/units.controller';
import { UnitsService } from './units/units.service';
import { CustomersController } from './customers/customers.controller';
import { CustomersService } from './customers/customers.service';
import { SuppliersController } from './suppliers/suppliers.controller';
import { SuppliersService } from './suppliers/suppliers.service';

@Module({
  imports: [DatabaseModule, AuthModule],
  controllers: [
    ProductsController,
    CategoriesController,
    UnitsController,
    CustomersController,
    SuppliersController,
  ],
  providers: [
    ProductsService,
    CategoriesService,
    UnitsService,
    CustomersService,
    SuppliersService,
  ],
  exports: [
    ProductsService,
    CategoriesService,
    UnitsService,
    CustomersService,
    SuppliersService,
  ],
})
export class MasterDataModule {}


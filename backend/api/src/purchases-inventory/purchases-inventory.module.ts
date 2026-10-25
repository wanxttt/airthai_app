import { Module } from '@nestjs/common';
import { PurchasesController } from './purchases.controller';
import { PurchasesService } from './purchases.service';
import { InventoryController } from './inventory.controller';
import { InventoryService } from './inventory.service';

@Module({
  controllers: [PurchasesController, InventoryController],
  providers: [PurchasesService, InventoryService],
  exports: [PurchasesService, InventoryService],
})
export class PurchasesInventoryModule {}

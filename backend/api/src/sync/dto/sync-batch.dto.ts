import { IsArray, IsEnum, IsInt, IsNotEmpty, IsObject, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export enum SyncEntityType {
  INVOICE = 'INVOICE',
  PURCHASE = 'PURCHASE',
  PAYMENT = 'PAYMENT',
  EXPENSE = 'EXPENSE',
  CUSTOMER = 'CUSTOMER',
  SUPPLIER = 'SUPPLIER',
  PRODUCT = 'PRODUCT',
}

export enum SyncOperationType {
  CREATE = 'CREATE',
  UPDATE = 'UPDATE',
  DELETE = 'DELETE',
}

export class SyncOperationItemDto {
  @IsString()
  @IsNotEmpty()
  clientOperationId!: string;

  @IsEnum(SyncEntityType)
  entityType!: SyncEntityType;

  @IsEnum(SyncOperationType)
  operation!: SyncOperationType;

  @IsString()
  @IsNotEmpty()
  entityId!: string;

  @IsOptional()
  @IsInt()
  version?: number;

  @IsObject()
  payload!: Record<string, any>;
}

export class SyncBatchDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncOperationItemDto)
  operations!: SyncOperationItemDto[];
}

export class SyncPullDto {
  @IsOptional()
  @IsString()
  since?: string;
}


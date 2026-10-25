import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { SuppliersService } from './suppliers.service';
import { CreateSupplierDto } from './dto/create-supplier.dto';
import { UpdateSupplierDto } from './dto/update-supplier.dto';
import { QuerySuppliersDto } from './dto/query-suppliers.dto';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { TenantGuard } from '../../auth/guards/tenant.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { CurrentUser, CurrentUserPayload } from '../../common/decorators/current-user.decorator';

@Controller('suppliers')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class SuppliersController {
  constructor(private readonly suppliersService: SuppliersService) {}

  @Post()
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  @HttpCode(HttpStatus.CREATED)
  async create(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateSupplierDto,
  ) {
    return await this.suppliersService.create(user.businessId, dto);
  }

  @Get()
  async findAll(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: QuerySuppliersDto,
  ) {
    return await this.suppliersService.findAll(user.businessId, query);
  }

  @Get(':id')
  async findOne(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return await this.suppliersService.findOne(user.businessId, id);
  }

  @Patch(':id')
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async update(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
    @Body() dto: UpdateSupplierDto,
  ) {
    return await this.suppliersService.update(user.businessId, id, dto);
  }

  @Patch(':id/archive')
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async toggleArchive(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return await this.suppliersService.toggleArchive(user.businessId, id);
  }

  @Delete(':id')
  @Roles('OWNER', 'ADMIN')
  async delete(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return await this.suppliersService.delete(user.businessId, id);
  }
}


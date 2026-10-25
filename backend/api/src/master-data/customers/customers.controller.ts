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
import { CustomersService } from './customers.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { UpdateCustomerDto } from './dto/update-customer.dto';
import { QueryCustomersDto } from './dto/query-customers.dto';
import { JwtAuthGuard } from '../../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { TenantGuard } from '../../auth/guards/tenant.guard';
import { Roles } from '../../auth/decorators/roles.decorator';
import { CurrentUser, CurrentUserPayload } from '../../common/decorators/current-user.decorator';

@Controller('customers')
@UseGuards(JwtAuthGuard, RolesGuard, TenantGuard)
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @Post()
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  @HttpCode(HttpStatus.CREATED)
  async create(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: CreateCustomerDto,
  ) {
    return await this.customersService.create(user.businessId, dto);
  }

  @Get()
  async findAll(
    @CurrentUser() user: CurrentUserPayload,
    @Query() query: QueryCustomersDto,
  ) {
    return await this.customersService.findAll(user.businessId, query);
  }

  @Get(':id')
  async findOne(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return await this.customersService.findOne(user.businessId, id);
  }

  @Patch(':id')
  @Roles('OWNER', 'ADMIN', 'MANAGER', 'STAFF')
  async update(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
    @Body() dto: UpdateCustomerDto,
  ) {
    return await this.customersService.update(user.businessId, id, dto);
  }

  @Patch(':id/archive')
  @Roles('OWNER', 'ADMIN', 'MANAGER')
  async toggleArchive(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return await this.customersService.toggleArchive(user.businessId, id);
  }

  @Delete(':id')
  @Roles('OWNER', 'ADMIN')
  async delete(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
  ) {
    return await this.customersService.delete(user.businessId, id);
  }
}


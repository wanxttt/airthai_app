import { IsEmail, IsNotEmpty, IsOptional, IsString, Length, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class RegisterDto {
  @IsString()
  @MinLength(2, { message: 'Full name must be at least 2 characters.' })
  fullName: string;

  @IsEmail({}, { message: 'Please provide a valid email address.' })
  @Transform(({ value }: { value?: string }) => value?.trim().toLowerCase())
  email: string;

  @IsString()
  @Length(10, 10, { message: 'Phone number must be exactly 10 digits.' })
  phone: string;

  @IsString()
  @MinLength(6, { message: 'Password must be at least 6 characters.' })
  password: string;

  @IsOptional()
  @IsString()
  businessName?: string;
}


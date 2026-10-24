import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';

export class LoginDto {
  @IsEmail({}, { message: 'Please provide a valid email address.' })
  @Transform(({ value }: { value?: string }) => value?.trim().toLowerCase())
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'Password is required.' })
  @MinLength(6, { message: 'Password must be at least 6 characters.' })
  password: string;
}


import { Test, TestingModule } from '@nestjs/testing';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';

describe('AuthController', () => {
  let controller: AuthController;
  let authService: Partial<AuthService>;

  beforeEach(async () => {
    authService = {
      register: jest.fn().mockResolvedValue({
        accessToken: 'mock_token',
        refreshToken: 'mock_refresh',
        token: 'mock_token',
        expiresIn: 3600,
        user: {
          id: 'usr_1',
          email: 'test@airthai.in',
          fullName: 'Test User',
          role: 'OWNER',
        },
      }),
      login: jest.fn().mockResolvedValue({
        accessToken: 'mock_token',
        refreshToken: 'mock_refresh',
        token: 'mock_token',
        expiresIn: 3600,
        user: {
          id: 'usr_1',
          email: 'test@airthai.in',
          fullName: 'Test User',
          role: 'OWNER',
        },
      }),
      refreshToken: jest.fn().mockResolvedValue({
        accessToken: 'new_token',
        refreshToken: 'new_refresh',
        expiresIn: 3600,
      }),
      logout: jest.fn().mockResolvedValue({
        success: true,
        message: 'Logged out successfully.',
      }),
      getMe: jest.fn().mockResolvedValue({
        id: 'usr_1',
        email: 'test@airthai.in',
        fullName: 'Test User',
        role: 'OWNER',
      }),
      updateBusinessSetup: jest.fn().mockResolvedValue({
        success: true,
        message: 'Business profile and setup updated successfully.',
        business: {
          id: 'biz_1',
          name: 'Updated Enterprise',
        },
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        {
          provide: AuthService,
          useValue: authService,
        },
      ],
    }).compile();

    controller = module.get<AuthController>(AuthController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('should handle register', async () => {
    const result = await controller.register({
      fullName: 'Test User',
      email: 'test@airthai.in',
      phone: '9876543210',
      password: 'Password123',
    });
    expect(authService.register).toHaveBeenCalled();
    expect(result).toHaveProperty('accessToken');
  });

  it('should handle login', async () => {
    const result = await controller.login({
      email: 'test@airthai.in',
      password: 'Password123',
    });
    expect(authService.login).toHaveBeenCalled();
    expect(result).toHaveProperty('accessToken');
  });

  it('should handle refresh', async () => {
    const result = await controller.refreshToken({ refreshToken: 'some_token' });
    expect(authService.refreshToken).toHaveBeenCalled();
    expect(result).toHaveProperty('accessToken');
  });

  it('should handle logout', async () => {
    const result = await controller.logout({ user: { id: 'usr_1' } });
    expect(authService.logout).toHaveBeenCalled();
    expect(result.success).toBe(true);
  });

  it('should handle getMe', async () => {
    const result = await controller.getMe({ user: { id: 'usr_1' } });
    expect(authService.getMe).toHaveBeenCalledWith('usr_1');
    expect(result).toHaveProperty('email', 'test@airthai.in');
  });

  it('should handle updateBusinessSetup', async () => {
    const req = { user: { id: 'usr_1', businessId: 'biz_1', role: 'OWNER' } };
    const dto = { businessName: 'Updated Enterprise' };
    const result = await controller.updateBusinessSetup(req, dto);

    expect(authService.updateBusinessSetup).toHaveBeenCalledWith('usr_1', 'biz_1', dto);
    expect(result.success).toBe(true);
    expect((result as any).business.name).toBe('Updated Enterprise');
  });
});


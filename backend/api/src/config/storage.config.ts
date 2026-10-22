import { registerAs } from '@nestjs/config';

export interface StorageConfig {
  provider: 'local' | 's3';
  s3Bucket?: string;
  awsRegion?: string;
}

export default registerAs(
  'storage',
  (): StorageConfig => ({
    provider: (process.env.STORAGE_PROVIDER as 'local' | 's3') || 'local',
    s3Bucket: process.env.S3_BUCKET || undefined,
    awsRegion: process.env.AWS_REGION || 'ap-south-1',
  }),
);


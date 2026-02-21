import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { numericTransformer } from '../../common/numeric.transformer';
import { OrderStatus } from '../order-status.enum';

@Entity({ name: 'orders' })
export class Order {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'uuid' })
  passengerId!: string;

  @Column({ type: 'uuid', nullable: true })
  driverId!: string | null;

  @Column({ type: 'varchar', length: 32 })
  status!: OrderStatus;

  @Column({ type: 'varchar', length: 64, nullable: true })
  cityId!: string | null;

  @Column({ type: 'double precision' })
  pickupLatitude!: number;

  @Column({ type: 'double precision' })
  pickupLongitude!: number;

  @Column({ type: 'double precision' })
  dropoffLatitude!: number;

  @Column({ type: 'double precision' })
  dropoffLongitude!: number;

  @Column({ type: 'double precision' })
  distanceKm!: number;

  @Column({ type: 'integer' })
  durationMinutes!: number;

  @Column({ type: 'numeric', precision: 10, scale: 2, transformer: numericTransformer })
  baseFare!: number;

  @Column({ type: 'numeric', precision: 10, scale: 2, transformer: numericTransformer })
  perKm!: number;

  @Column({ type: 'numeric', precision: 10, scale: 2, transformer: numericTransformer })
  perMinute!: number;

  @Column({ type: 'numeric', precision: 5, scale: 2, transformer: numericTransformer })
  surgeMultiplier!: number;

  @Column({ type: 'numeric', precision: 10, scale: 2, transformer: numericTransformer })
  finalPrice!: number;

  @CreateDateColumn({ type: 'timestamptz' })
  createdAt!: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updatedAt!: Date;
}

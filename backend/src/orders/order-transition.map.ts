import { OrderStatus } from './order-status.enum';

const ALLOWED_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  [OrderStatus.CREATED]: [OrderStatus.SEARCHING_DRIVER, OrderStatus.CANCELED],
  [OrderStatus.SEARCHING_DRIVER]: [OrderStatus.DRIVER_ASSIGNED, OrderStatus.CANCELED],
  [OrderStatus.DRIVER_ASSIGNED]: [OrderStatus.DRIVER_ARRIVING, OrderStatus.CANCELED],
  [OrderStatus.DRIVER_ARRIVING]: [OrderStatus.IN_PROGRESS, OrderStatus.CANCELED],
  [OrderStatus.IN_PROGRESS]: [OrderStatus.COMPLETED, OrderStatus.CANCELED],
  [OrderStatus.COMPLETED]: [],
  [OrderStatus.CANCELED]: [],
};

export function isTransitionAllowed(from: OrderStatus, to: OrderStatus): boolean {
  return ALLOWED_TRANSITIONS[from].includes(to);
}

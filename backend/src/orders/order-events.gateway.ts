import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Order } from './entities/order.entity';

@WebSocketGateway({ namespace: '/orders', cors: { origin: '*' } })
export class OrderEventsGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  private server!: Server;

  handleConnection(_client: Socket): void {
    // Connection hook reserved for auth/rate-limit in next iteration.
  }

  handleDisconnect(_client: Socket): void {
    // Disconnect hook reserved for cleanup logic.
  }

  @SubscribeMessage('order.subscribe')
  handleOrderSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { orderId: string },
  ): { ok: true } {
    if (payload?.orderId) {
      client.join(payload.orderId);
    }

    return { ok: true };
  }

  emitOrderUpdated(order: Order): void {
    if (!this.server) {
      return;
    }

    const event = this.toEvent(order);
    this.server.emit('order.updated', event);
    this.server.to(order.id).emit('order.updated', event);
  }

  private toEvent(order: Order): Record<string, unknown> {
    return {
      id: order.id,
      passengerId: order.passengerId,
      driverId: order.driverId,
      status: order.status,
      finalPrice: order.finalPrice,
      updatedAt: order.updatedAt,
    };
  }
}

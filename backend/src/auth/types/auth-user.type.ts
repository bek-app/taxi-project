import { UserRole } from '../user-role.enum';

export interface AuthUser {
  userId: string;
  email: string;
  role: UserRole;
}

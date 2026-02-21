import { UserRole } from '../user-role.enum';

export interface AuthResponse {
  accessToken: string;
  user: {
    id: string;
    email: string;
    role: UserRole;
  };
}

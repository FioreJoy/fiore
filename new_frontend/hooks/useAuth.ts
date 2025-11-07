
import { useContext } from 'react';
// The context is created and exported from AuthContext.tsx, but we can't import it that way due to file structure rules.
// So, we just re-import from the source file.
import { useAuth as useAuthFromContext } from '../contexts/AuthContext';

export const useAuth = useAuthFromContext;

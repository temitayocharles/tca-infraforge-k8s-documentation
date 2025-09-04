# 🚀 Chapter 8: Enterprise Applications

## 🎯 Learning Objectives
By the end of this chapter, you'll understand:
- How to architect backend APIs with FastAPI and Flask
- Frontend application design with modern frameworks
- Database integration patterns with PostgreSQL and Redis
- Microservices architecture and communication patterns

**⏱️ Time to Complete:** 30-35 minutes  
**💡 Difficulty:** Intermediate to Advanced  
**🎯 Prerequisites:** Understanding of web development and database concepts

---

## 🌟 Enterprise Application Architecture

TCA InfraForge implements a **modern microservices architecture** that ensures scalability, maintainability, and reliability. This chapter covers the application patterns that power enterprise-grade solutions.

### Why Microservices Matter?
- **📈 Scalability**: Independent scaling of services
- **🔧 Maintainability**: Smaller, focused codebases
- **🚀 Deployability**: Independent deployment cycles
- **🔒 Resilience**: Fault isolation between services
- **👥 Team autonomy**: Independent development teams

**Real-world analogy:** Think of microservices as a well-organized factory where each machine has a specific job, works independently, but contributes to the final product!

---

## 🔧 Backend API Architecture

### FastAPI Backend Service

#### Project Structure
```
tca-api/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   └── project.py
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── user.py
│   │   └── project.py
│   ├── routers/
│   │   ├── __init__.py
│   │   ├── users.py
│   │   ├── projects.py
│   │   └── health.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── user_service.py
│   │   └── project_service.py
│   ├── dependencies/
│   │   ├── __init__.py
│   │   ├── auth.py
│   │   └── database.py
│   └── utils/
│       ├── __init__.py
│       ├── security.py
│       └── pagination.py
├── tests/
│   ├── __init__.py
│   ├── test_users.py
│   └── test_projects.py
├── requirements.txt
├── Dockerfile
└── docker-compose.yml
```

#### Main Application
```python
# app/main.py
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.config import settings
from app.database import create_tables
from app.routers import users, projects, health
from app.utils.logging import setup_logging

# Setup logging
setup_logging()

# Create FastAPI app
app = FastAPI(
    title="TCA InfraForge API",
    description="Enterprise API for TCA InfraForge platform",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json"
)

# Rate limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security middleware
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=settings.ALLOWED_HOSTS
)

# Database initialization
@app.on_event("startup")
async def startup_event():
    """Initialize database on startup."""
    await create_tables()

# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler for unhandled exceptions."""
    logger = request.app.state.logger
    logger.error(f"Unhandled exception: {exc}", exc_info=True)

    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"}
    )

# Include routers
app.include_router(
    health.router,
    prefix="/health",
    tags=["Health"]
)

app.include_router(
    users.router,
    prefix="/api/v1/users",
    tags=["Users"]
)

app.include_router(
    projects.router,
    prefix="/api/v1/projects",
    tags=["Projects"]
)

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": "TCA InfraForge API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info"
    )
```

#### Configuration Management
```python
# app/config.py
from pydantic import BaseSettings, validator
from typing import List, Optional
import secrets

class Settings(BaseSettings):
    """Application settings with validation."""

    # Application
    APP_NAME: str = "TCA InfraForge API"
    DEBUG: bool = False
    SECRET_KEY: str = secrets.token_urlsafe(32)

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    ALLOWED_HOSTS: List[str] = ["*"]
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "https://app.tca-infraforge.com"]

    # Database
    DATABASE_URL: str = "postgresql://user:password@localhost:5432/tca_db"
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 20

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_CACHE_TTL: int = 3600

    # Security
    JWT_SECRET_KEY: str = secrets.token_urlsafe(32)
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # External Services
    GITHUB_CLIENT_ID: Optional[str] = None
    GITHUB_CLIENT_SECRET: Optional[str] = None
    SLACK_WEBHOOK_URL: Optional[str] = None

    # Monitoring
    SENTRY_DSN: Optional[str] = None
    PROMETHEUS_ENABLED: bool = True

    @validator("DATABASE_URL", pre=True)
    def validate_database_url(cls, v):
        """Validate database URL format."""
        if not v.startswith(("postgresql://", "postgresql+asyncpg://")):
            raise ValueError("Database URL must be a valid PostgreSQL URL")
        return v

    @validator("ALLOWED_ORIGINS", each_item=True)
    def validate_origins(cls, v):
        """Validate CORS origins."""
        if not v.startswith(("http://", "https://")):
            raise ValueError("Origins must start with http:// or https://")
        return v

    class Config:
        env_file = ".env"
        case_sensitive = True

# Global settings instance
settings = Settings()
```

#### Database Models
```python
# app/models/user.py
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class User(Base):
    """User model for authentication and authorization."""

    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(50), unique=True, index=True, nullable=False)
    full_name = Column(String(100))
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    projects = relationship("Project", back_populates="owner")

    def __repr__(self):
        return f"<User(id={self.id}, email={self.email})>"
```

#### API Schemas
```python
# app/schemas/user.py
from pydantic import BaseModel, EmailStr, validator
from typing import Optional
from datetime import datetime

class UserBase(BaseModel):
    """Base user schema."""
    email: EmailStr
    username: str
    full_name: Optional[str] = None
    is_active: bool = True

    @validator("username")
    def username_alphanumeric(cls, v):
        """Validate username contains only alphanumeric characters."""
        assert v.isalnum(), "Username must be alphanumeric"
        return v

class UserCreate(UserBase):
    """Schema for creating users."""
    password: str

    @validator("password")
    def password_strength(cls, v):
        """Validate password strength."""
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not any(char.isdigit() for char in v):
            raise ValueError("Password must contain at least one digit")
        if not any(char.isupper() for char in v):
            raise ValueError("Password must contain at least one uppercase letter")
        return v

class UserUpdate(BaseModel):
    """Schema for updating users."""
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None

class UserResponse(UserBase):
    """Schema for user responses."""
    id: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        orm_mode = True

class UserLogin(BaseModel):
    """Schema for user login."""
    username: str
    password: str

class Token(BaseModel):
    """Schema for authentication tokens."""
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    refresh_token: str

class TokenData(BaseModel):
    """Schema for token payload."""
    username: Optional[str] = None
    user_id: Optional[int] = None
```

#### API Router
```python
# app/routers/users.py
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate, UserResponse, Token
from app.services.user_service import UserService
from app.dependencies.auth import get_current_user, get_current_active_user
from app.utils.pagination import paginate
from app.utils.security import verify_password, create_access_token

router = APIRouter()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

@router.post("/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    user: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Create a new user."""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )

    user_service = UserService(db)
    try:
        db_user = await user_service.create_user(user)
        return db_user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.get("/", response_model=List[UserResponse])
async def read_users(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get list of users with pagination."""
    users = await UserService(db).get_users(skip=skip, limit=limit)
    return users

@router.get("/{user_id}", response_model=UserResponse)
async def read_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Get user by ID."""
    user_service = UserService(db)
    user = await user_service.get_user(user_id)

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    # Users can only see their own profile unless they're superusers
    if user.id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )

    return user

@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: int,
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Update user information."""
    user_service = UserService(db)
    user = await user_service.get_user(user_id)

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    # Users can only update their own profile unless they're superusers
    if user.id != current_user.id and not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )

    try:
        updated_user = await user_service.update_user(user_id, user_update)
        return updated_user
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_user)
):
    """Delete user by ID."""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions"
        )

    user_service = UserService(db)
    success = await user_service.delete_user(user_id)

    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
```

---

## 🎨 Frontend Application Design

### Next.js Frontend Architecture

#### Project Structure
```
tca-frontend/
├── components/
│   ├── layout/
│   │   ├── Header.tsx
│   │   ├── Sidebar.tsx
│   │   └── Footer.tsx
│   ├── ui/
│   │   ├── Button.tsx
│   │   ├── Input.tsx
│   │   ├── Modal.tsx
│   │   └── Table.tsx
│   ├── forms/
│   │   ├── LoginForm.tsx
│   │   ├── UserForm.tsx
│   │   └── ProjectForm.tsx
│   └── dashboard/
│       ├── Dashboard.tsx
│       ├── MetricsCard.tsx
│       └── Charts.tsx
├── pages/
│   ├── _app.tsx
│   ├── _document.tsx
│   ├── index.tsx
│   ├── login.tsx
│   ├── dashboard.tsx
│   ├── users/
│   │   ├── index.tsx
│   │   └── [id].tsx
│   └── projects/
│       ├── index.tsx
│       └── [id].tsx
├── lib/
│   ├── api.ts
│   ├── auth.ts
│   ├── config.ts
│   └── utils.ts
├── hooks/
│   ├── useAuth.ts
│   ├── useUsers.ts
│   ├── useProjects.ts
│   └── useApi.ts
├── styles/
│   ├── globals.css
│   └── theme.ts
├── types/
│   ├── user.ts
│   ├── project.ts
│   └── api.ts
├── public/
│   ├── favicon.ico
│   └── images/
├── next.config.js
├── package.json
└── tsconfig.json
```

#### Main Application
```tsx
// pages/_app.tsx
import { AppProps } from 'next/app';
import { ThemeProvider } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import { CacheProvider } from '@emotion/react';
import { AuthProvider } from '../lib/auth';
import { ApiProvider } from '../lib/api';
import theme from '../styles/theme';
import createEmotionCache from '../lib/createEmotionCache';

const clientSideEmotionCache = createEmotionCache();

function MyApp({ Component, pageProps, emotionCache = clientSideEmotionCache }: AppProps & { emotionCache?: any }) {
  return (
    <CacheProvider value={emotionCache}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <AuthProvider>
          <ApiProvider>
            <Component {...pageProps} />
          </ApiProvider>
        </AuthProvider>
      </ThemeProvider>
    </CacheProvider>
  );
}

export default MyApp;
```

#### Authentication Context
```tsx
// lib/auth.tsx
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { useRouter } from 'next/router';
import { User } from '../types/user';

interface AuthContextType {
  user: User | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  loading: boolean;
  isAuthenticated: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    // Check for existing session
    const checkAuth = async () => {
      try {
        const token = localStorage.getItem('access_token');
        if (token) {
          // Validate token with API
          const response = await fetch('/api/auth/verify', {
            headers: {
              'Authorization': `Bearer ${token}`
            }
          });

          if (response.ok) {
            const userData = await response.json();
            setUser(userData);
          } else {
            localStorage.removeItem('access_token');
            localStorage.removeItem('refresh_token');
          }
        }
      } catch (error) {
        console.error('Auth check failed:', error);
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, []);

  const login = async (email: string, password: string) => {
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      });

      if (!response.ok) {
        throw new Error('Login failed');
      }

      const data = await response.json();
      localStorage.setItem('access_token', data.access_token);
      localStorage.setItem('refresh_token', data.refresh_token);
      setUser(data.user);

      router.push('/dashboard');
    } catch (error) {
      throw error;
    }
  };

  const logout = () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    setUser(null);
    router.push('/login');
  };

  const value = {
    user,
    login,
    logout,
    loading,
    isAuthenticated: !!user,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};
```

#### API Integration
```tsx
// lib/api.ts
import { User, Project } from '../types';

class ApiClient {
  private baseURL: string;
  private token: string | null = null;

  constructor(baseURL: string = '/api') {
    this.baseURL = baseURL;
    if (typeof window !== 'undefined') {
      this.token = localStorage.getItem('access_token');
    }
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      if (response.status === 401) {
        // Token expired, redirect to login
        if (typeof window !== 'undefined') {
          localStorage.removeItem('access_token');
          window.location.href = '/login';
        }
      }
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  }

  // User API methods
  async getUsers(params?: { page?: number; limit?: number }): Promise<User[]> {
    const query = params ? `?${new URLSearchParams(params as any)}` : '';
    return this.request<User[]>(`/users${query}`);
  }

  async getUser(id: number): Promise<User> {
    return this.request<User>(`/users/${id}`);
  }

  async createUser(user: Omit<User, 'id'>): Promise<User> {
    return this.request<User>('/users', {
      method: 'POST',
      body: JSON.stringify(user),
    });
  }

  async updateUser(id: number, user: Partial<User>): Promise<User> {
    return this.request<User>(`/users/${id}`, {
      method: 'PUT',
      body: JSON.stringify(user),
    });
  }

  async deleteUser(id: number): Promise<void> {
    return this.request<void>(`/users/${id}`, {
      method: 'DELETE',
    });
  }

  // Project API methods
  async getProjects(params?: { page?: number; limit?: number }): Promise<Project[]> {
    const query = params ? `?${new URLSearchParams(params as any)}` : '';
    return this.request<Project[]>(`/projects${query}`);
  }

  async getProject(id: number): Promise<Project> {
    return this.request<Project>(`/projects/${id}`);
  }

  async createProject(project: Omit<Project, 'id'>): Promise<Project> {
    return this.request<Project>('/projects', {
      method: 'POST',
      body: JSON.stringify(project),
    });
  }

  async updateProject(id: number, project: Partial<Project>): Promise<Project> {
    return this.request<Project>(`/projects/${id}`, {
      method: 'PUT',
      body: JSON.stringify(project),
    });
  }

  async deleteProject(id: number): Promise<void> {
    return this.request<void>(`/projects/${id}`, {
      method: 'DELETE',
    });
  }
}

export const apiClient = new ApiClient();

// React hook for API calls
export const useApi = () => {
  return apiClient;
};
```

#### Dashboard Component
```tsx
// components/dashboard/Dashboard.tsx
import React, { useState, useEffect } from 'react';
import {
  Grid,
  Card,
  CardContent,
  Typography,
  Box,
  CircularProgress,
  Alert,
} from '@mui/material';
import { useAuth } from '../../lib/auth';
import { useApi } from '../../lib/api';
import MetricsCard from './MetricsCard';
import RecentActivity from './RecentActivity';
import SystemHealth from './SystemHealth';

const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const api = useApi();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalProjects: 0,
    activeDeployments: 0,
    systemHealth: 95,
  });

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        setLoading(true);

        // Fetch dashboard statistics
        const [usersResponse, projectsResponse] = await Promise.all([
          api.getUsers({ limit: 1 }), // Just get count
          api.getProjects({ limit: 1 }), // Just get count
        ]);

        setStats({
          totalUsers: usersResponse.length, // This would be from pagination metadata
          totalProjects: projectsResponse.length,
          activeDeployments: 12, // This would come from deployments API
          systemHealth: 95,
        });
      } catch (err) {
        setError('Failed to load dashboard data');
        console.error('Dashboard error:', err);
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, [api]);

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" alignItems="center" minHeight="400px">
        <CircularProgress />
      </Box>
    );
  }

  if (error) {
    return (
      <Alert severity="error" sx={{ mb: 2 }}>
        {error}
      </Alert>
    );
  }

  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        Welcome back, {user?.full_name || user?.username}!
      </Typography>

      <Typography variant="body1" color="text.secondary" sx={{ mb: 4 }}>
        Here's what's happening with your TCA InfraForge platform.
      </Typography>

      <Grid container spacing={3}>
        <Grid item xs={12} sm={6} md={3}>
          <MetricsCard
            title="Total Users"
            value={stats.totalUsers}
            icon="👥"
            trend="+12%"
            trendUp={true}
          />
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <MetricsCard
            title="Active Projects"
            value={stats.totalProjects}
            icon="📁"
            trend="+8%"
            trendUp={true}
          />
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <MetricsCard
            title="Deployments"
            value={stats.activeDeployments}
            icon="🚀"
            trend="+15%"
            trendUp={true}
          />
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <MetricsCard
            title="System Health"
            value={`${stats.systemHealth}%`}
            icon="❤️"
            trend="+2%"
            trendUp={true}
          />
        </Grid>

        <Grid item xs={12} md={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" component="h2" gutterBottom>
                Recent Activity
              </Typography>
              <RecentActivity />
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" component="h2" gutterBottom>
                System Health
              </Typography>
              <SystemHealth health={stats.systemHealth} />
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
};

export default Dashboard;
```

---

## 🗄️ Database Integration

### PostgreSQL with SQLAlchemy

#### Database Configuration
```python
# app/database.py
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool
from contextlib import contextmanager
import logging

from app.config import settings

logger = logging.getLogger(__name__)

# Create engine with connection pooling
engine = create_engine(
    settings.DATABASE_URL,
    poolclass=QueuePool,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    pool_pre_ping=True,  # Verify connections before use
    echo=settings.DEBUG,  # SQL query logging in debug mode
)

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Create Base class for models
Base = declarative_base()

@contextmanager
def get_db() -> Session:
    """Dependency for getting database session."""
    db = SessionLocal()
    try:
        yield db
    except Exception as e:
        logger.error(f"Database error: {e}")
        db.rollback()
        raise
    finally:
        db.close()

async def create_tables():
    """Create all database tables."""
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables created successfully")
    except Exception as e:
        logger.error(f"Failed to create database tables: {e}")
        raise

async def drop_tables():
    """Drop all database tables."""
    try:
        Base.metadata.drop_all(bind=engine)
        logger.info("Database tables dropped successfully")
    except Exception as e:
        logger.error(f"Failed to drop database tables: {e}")
        raise
```

#### Repository Pattern
```python
# app/repositories/base.py
from abc import ABC, abstractmethod
from typing import List, Optional, TypeVar, Generic
from sqlalchemy.orm import Session
from sqlalchemy import desc

T = TypeVar('T')

class BaseRepository(ABC, Generic[T]):
    """Base repository with common CRUD operations."""

    def __init__(self, db: Session):
        self.db = db

    @abstractmethod
    def get_by_id(self, id: int) -> Optional[T]:
        """Get entity by ID."""
        pass

    @abstractmethod
    def get_all(self, skip: int = 0, limit: int = 100) -> List[T]:
        """Get all entities with pagination."""
        pass

    @abstractmethod
    def create(self, entity: T) -> T:
        """Create new entity."""
        pass

    @abstractmethod
    def update(self, id: int, entity: T) -> Optional[T]:
        """Update existing entity."""
        pass

    @abstractmethod
    def delete(self, id: int) -> bool:
        """Delete entity by ID."""
        pass

    def save(self):
        """Commit changes to database."""
        try:
            self.db.commit()
        except Exception as e:
            self.db.rollback()
            raise e

    def refresh(self, entity: T):
        """Refresh entity from database."""
        self.db.refresh(entity)
```

#### User Repository
```python
# app/repositories/user_repository.py
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.models.user import User
from app.repositories.base import BaseRepository

class UserRepository(BaseRepository[User]):
    """Repository for User model operations."""

    def __init__(self, db: Session):
        super().__init__(db)

    def get_by_id(self, user_id: int) -> Optional[User]:
        """Get user by ID."""
        return self.db.query(User).filter(User.id == user_id).first()

    def get_by_email(self, email: str) -> Optional[User]:
        """Get user by email."""
        return self.db.query(User).filter(User.email == email).first()

    def get_by_username(self, username: str) -> Optional[User]:
        """Get user by username."""
        return self.db.query(User).filter(User.username == username).first()

    def get_all(self, skip: int = 0, limit: int = 100) -> List[User]:
        """Get all users with pagination."""
        return (
            self.db.query(User)
            .order_by(User.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def search_users(self, query: str, skip: int = 0, limit: int = 100) -> List[User]:
        """Search users by name or email."""
        search_filter = or_(
            User.email.ilike(f"%{query}%"),
            User.username.ilike(f"%{query}%"),
            User.full_name.ilike(f"%{query}%")
        )
        return (
            self.db.query(User)
            .filter(search_filter)
            .order_by(User.created_at.desc())
            .offset(skip)
            .limit(limit)
            .all()
        )

    def create(self, user_data: dict) -> User:
        """Create new user."""
        user = User(**user_data)
        self.db.add(user)
        self.save()
        self.refresh(user)
        return user

    def update(self, user_id: int, user_data: dict) -> Optional[User]:
        """Update existing user."""
        user = self.get_by_id(user_id)
        if user:
            for key, value in user_data.items():
                if hasattr(user, key):
                    setattr(user, key, value)
            self.save()
            self.refresh(user)
        return user

    def delete(self, user_id: int) -> bool:
        """Delete user by ID."""
        user = self.get_by_id(user_id)
        if user:
            self.db.delete(user)
            self.save()
            return True
        return False

    def count_active_users(self) -> int:
        """Count active users."""
        return self.db.query(User).filter(User.is_active == True).count()
```

### Redis Caching Layer

#### Redis Configuration
```python
# app/cache/redis.py
import redis
import json
from typing import Any, Optional, Union
from app.config import settings
import logging

logger = logging.getLogger(__name__)

class RedisCache:
    """Redis cache implementation."""

    def __init__(self):
        self.redis_client = redis.from_url(settings.REDIS_URL)

    def get(self, key: str) -> Optional[Any]:
        """Get value from cache."""
        try:
            value = self.redis_client.get(key)
            if value:
                return json.loads(value)
            return None
        except Exception as e:
            logger.error(f"Redis get error: {e}")
            return None

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> bool:
        """Set value in cache with optional TTL."""
        try:
            serialized_value = json.dumps(value)
            if ttl:
                return bool(self.redis_client.setex(key, ttl, serialized_value))
            else:
                return bool(self.redis_client.set(key, serialized_value))
        except Exception as e:
            logger.error(f"Redis set error: {e}")
            return False

    def delete(self, key: str) -> bool:
        """Delete value from cache."""
        try:
            return bool(self.redis_client.delete(key))
        except Exception as e:
            logger.error(f"Redis delete error: {e}")
            return False

    def exists(self, key: str) -> bool:
        """Check if key exists in cache."""
        try:
            return bool(self.redis_client.exists(key))
        except Exception as e:
            logger.error(f"Redis exists error: {e}")
            return False

    def expire(self, key: str, ttl: int) -> bool:
        """Set expiration time for key."""
        try:
            return bool(self.redis_client.expire(key, ttl))
        except Exception as e:
            logger.error(f"Redis expire error: {e}")
            return False

    def incr(self, key: str) -> Optional[int]:
        """Increment integer value."""
        try:
            return self.redis_client.incr(key)
        except Exception as e:
            logger.error(f"Redis incr error: {e}")
            return None

    def publish(self, channel: str, message: Any) -> bool:
        """Publish message to channel."""
        try:
            return bool(self.redis_client.publish(channel, json.dumps(message)))
        except Exception as e:
            logger.error(f"Redis publish error: {e}")
            return False

    def subscribe(self, channel: str):
        """Subscribe to channel."""
        try:
            pubsub = self.redis_client.pubsub()
            pubsub.subscribe(channel)
            return pubsub
        except Exception as e:
            logger.error(f"Redis subscribe error: {e}")
            return None

# Global cache instance
cache = RedisCache()
```

#### Service Layer with Caching
```python
# app/services/user_service.py
from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from app.repositories.user_repository import UserRepository
from app.cache.redis import cache
from app.utils.security import hash_password, verify_password
from app.config import settings
import logging

logger = logging.getLogger(__name__)

class UserService:
    """Service layer for user operations."""

    def __init__(self, db: Session):
        self.db = db
        self.repository = UserRepository(db)
        self.cache_ttl = settings.REDIS_CACHE_TTL

    async def get_user(self, user_id: int) -> Optional[Dict[str, Any]]:
        """Get user by ID with caching."""
        cache_key = f"user:{user_id}"

        # Try cache first
        cached_user = cache.get(cache_key)
        if cached_user:
            logger.info(f"User {user_id} retrieved from cache")
            return cached_user

        # Get from database
        user = self.repository.get_by_id(user_id)
        if user:
            user_dict = {
                "id": user.id,
                "email": user.email,
                "username": user.username,
                "full_name": user.full_name,
                "is_active": user.is_active,
                "created_at": user.created_at.isoformat(),
                "updated_at": user.updated_at.isoformat() if user.updated_at else None,
            }

            # Cache the result
            cache.set(cache_key, user_dict, self.cache_ttl)
            logger.info(f"User {user_id} cached")

            return user_dict

        return None

    async def get_users(self, skip: int = 0, limit: int = 100, search: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get users with optional search and caching."""
        cache_key = f"users:{skip}:{limit}:{search or ''}"

        # Try cache first
        cached_users = cache.get(cache_key)
        if cached_users:
            logger.info("Users list retrieved from cache")
            return cached_users

        # Get from database
        if search:
            users = self.repository.search_users(search, skip, limit)
        else:
            users = self.repository.get_all(skip, limit)

        users_list = []
        for user in users:
            users_list.append({
                "id": user.id,
                "email": user.email,
                "username": user.username,
                "full_name": user.full_name,
                "is_active": user.is_active,
                "created_at": user.created_at.isoformat(),
                "updated_at": user.updated_at.isoformat() if user.updated_at else None,
            })

        # Cache the result
        cache.set(cache_key, users_list, self.cache_ttl)

        return users_list

    async def create_user(self, user_data: Dict[str, Any]) -> Dict[str, Any]:
        """Create new user."""
        # Check if user already exists
        existing_user = self.repository.get_by_email(user_data["email"])
        if existing_user:
            raise ValueError("User with this email already exists")

        existing_username = self.repository.get_by_username(user_data["username"])
        if existing_username:
            raise ValueError("Username already taken")

        # Hash password
        hashed_password = hash_password(user_data["password"])

        # Create user
        user_dict = {
            "email": user_data["email"],
            "username": user_data["username"],
            "full_name": user_data.get("full_name"),
            "hashed_password": hashed_password,
            "is_active": user_data.get("is_active", True),
        }

        user = self.repository.create(user_dict)

        # Invalidate cache
        cache.delete("users:*")

        result = {
            "id": user.id,
            "email": user.email,
            "username": user.username,
            "full_name": user.full_name,
            "is_active": user.is_active,
            "created_at": user.created_at.isoformat(),
            "updated_at": user.updated_at.isoformat() if user.updated_at else None,
        }

        return result

    async def update_user(self, user_id: int, user_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Update user."""
        # Check if user exists
        existing_user = self.repository.get_by_id(user_id)
        if not existing_user:
            raise ValueError("User not found")

        # Check email uniqueness if email is being updated
        if "email" in user_data and user_data["email"] != existing_user.email:
            email_user = self.repository.get_by_email(user_data["email"])
            if email_user and email_user.id != user_id:
                raise ValueError("Email already taken")

        # Check username uniqueness if username is being updated
        if "username" in user_data and user_data["username"] != existing_user.username:
            username_user = self.repository.get_by_username(user_data["username"])
            if username_user and username_user.id != user_id:
                raise ValueError("Username already taken")

        # Hash password if provided
        if "password" in user_data:
            user_data["hashed_password"] = hash_password(user_data["password"])
            del user_data["password"]

        # Update user
        updated_user = self.repository.update(user_id, user_data)

        if updated_user:
            # Invalidate cache
            cache.delete(f"user:{user_id}")
            cache.delete("users:*")

            result = {
                "id": updated_user.id,
                "email": updated_user.email,
                "username": updated_user.username,
                "full_name": updated_user.full_name,
                "is_active": updated_user.is_active,
                "created_at": updated_user.created_at.isoformat(),
                "updated_at": updated_user.updated_at.isoformat() if updated_user.updated_at else None,
            }

            return result

        return None

    async def delete_user(self, user_id: int) -> bool:
        """Delete user."""
        success = self.repository.delete(user_id)

        if success:
            # Invalidate cache
            cache.delete(f"user:{user_id}")
            cache.delete("users:*")

        return success

    async def authenticate_user(self, username: str, password: str) -> Optional[Dict[str, Any]]:
        """Authenticate user."""
        # Get user by username or email
        user = self.repository.get_by_username(username)
        if not user:
            user = self.repository.get_by_email(username)
        if not user:
            return None

        # Verify password
        if not verify_password(password, user.hashed_password):
            return None

        # Check if user is active
        if not user.is_active:
            return None

        return {
            "id": user.id,
            "email": user.email,
            "username": user.username,
            "full_name": user.full_name,
            "is_active": user.is_active,
            "is_superuser": user.is_superuser,
        }
```

---

## 🔄 Microservices Communication

### Synchronous Communication

#### REST API Client
```python
# app/services/api_client.py
import httpx
import json
from typing import Dict, Any, Optional
from app.config import settings
import logging

logger = logging.getLogger(__name__)

class APIClient:
    """HTTP client for inter-service communication."""

    def __init__(self, base_url: str, timeout: float = 30.0):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout

    async def get(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """GET request."""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.get(f"{self.base_url}{endpoint}", params=params)
                response.raise_for_status()
                return response.json()
            except httpx.HTTPError as e:
                logger.error(f"GET {endpoint} failed: {e}")
                raise

    async def post(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """POST request."""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.post(
                    f"{self.base_url}{endpoint}",
                    json=data,
                    headers={"Content-Type": "application/json"}
                )
                response.raise_for_status()
                return response.json()
            except httpx.HTTPError as e:
                logger.error(f"POST {endpoint} failed: {e}")
                raise

    async def put(self, endpoint: str, data: Dict[str, Any]) -> Dict[str, Any]:
        """PUT request."""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.put(
                    f"{self.base_url}{endpoint}",
                    json=data,
                    headers={"Content-Type": "application/json"}
                )
                response.raise_for_status()
                return response.json()
            except httpx.HTTPError as e:
                logger.error(f"PUT {endpoint} failed: {e}")
                raise

    async def delete(self, endpoint: str) -> bool:
        """DELETE request."""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            try:
                response = await client.delete(f"{self.base_url}{endpoint}")
                response.raise_for_status()
                return True
            except httpx.HTTPError as e:
                logger.error(f"DELETE {endpoint} failed: {e}")
                return False

# Service clients
user_service_client = APIClient(f"{settings.USER_SERVICE_URL}")
notification_service_client = APIClient(f"{settings.NOTIFICATION_SERVICE_URL}")
analytics_service_client = APIClient(f"{settings.ANALYTICS_SERVICE_URL}")
```

### Asynchronous Communication

#### Message Queue with Redis
```python
# app/services/message_queue.py
import json
from typing import Dict, Any, Callable
from app.cache.redis import cache
import asyncio
import logging

logger = logging.getLogger(__name__)

class MessageQueue:
    """Simple message queue using Redis pub/sub."""

    def __init__(self):
        self.pubsub = None

    async def publish(self, channel: str, message: Dict[str, Any]) -> bool:
        """Publish message to channel."""
        return cache.publish(channel, message)

    async def subscribe(self, channel: str, callback: Callable[[Dict[str, Any]], None]):
        """Subscribe to channel with callback."""
        if not self.pubsub:
            self.pubsub = cache.subscribe(channel)

        if self.pubsub:
            try:
                for message in self.pubsub.listen():
                    if message['type'] == 'message':
                        try:
                            data = json.loads(message['data'])
                            await callback(data)
                        except json.JSONDecodeError as e:
                            logger.error(f"Invalid message format: {e}")
            except Exception as e:
                logger.error(f"Subscription error: {e}")

    async def publish_user_event(self, event_type: str, user_id: int, data: Dict[str, Any]):
        """Publish user-related event."""
        message = {
            "event_type": event_type,
            "user_id": user_id,
            "timestamp": asyncio.get_event_loop().time(),
            "data": data
        }
        await self.publish("user_events", message)

    async def publish_project_event(self, event_type: str, project_id: int, data: Dict[str, Any]):
        """Publish project-related event."""
        message = {
            "event_type": event_type,
            "project_id": project_id,
            "timestamp": asyncio.get_event_loop().time(),
            "data": data
        }
        await self.publish("project_events", message)

# Global message queue instance
message_queue = MessageQueue()
```

#### Event-Driven Architecture
```python
# app/services/event_service.py
from typing import Dict, Any
from app.services.message_queue import message_queue
import logging

logger = logging.getLogger(__name__)

class EventService:
    """Service for handling application events."""

    @staticmethod
    async def user_created(user_id: int, user_data: Dict[str, Any]):
        """Handle user creation event."""
        try:
            await message_queue.publish_user_event("user_created", user_id, user_data)

            # Send welcome email (async)
            await message_queue.publish("email_queue", {
                "type": "welcome_email",
                "user_id": user_id,
                "email": user_data["email"],
                "name": user_data.get("full_name") or user_data["username"]
            })

            # Update analytics
            await message_queue.publish("analytics_queue", {
                "event": "user_registered",
                "user_id": user_id,
                "timestamp": user_data.get("created_at")
            })

            logger.info(f"User creation events published for user {user_id}")

        except Exception as e:
            logger.error(f"Failed to publish user creation events: {e}")

    @staticmethod
    async def user_updated(user_id: int, old_data: Dict[str, Any], new_data: Dict[str, Any]):
        """Handle user update event."""
        try:
            changes = {}
            for key in new_data:
                if key in old_data and old_data[key] != new_data[key]:
                    changes[key] = {"old": old_data[key], "new": new_data[key]}

            if changes:
                await message_queue.publish_user_event("user_updated", user_id, {
                    "changes": changes,
                    "updated_data": new_data
                })

                logger.info(f"User update events published for user {user_id}")

        except Exception as e:
            logger.error(f"Failed to publish user update events: {e}")

    @staticmethod
    async def project_created(project_id: int, project_data: Dict[str, Any]):
        """Handle project creation event."""
        try:
            await message_queue.publish_project_event("project_created", project_id, project_data)

            # Notify team members
            if "team_members" in project_data:
                await message_queue.publish("notification_queue", {
                    "type": "project_invitation",
                    "project_id": project_id,
                    "project_name": project_data["name"],
                    "team_members": project_data["team_members"]
                })

            logger.info(f"Project creation events published for project {project_id}")

        except Exception as e:
            logger.error(f"Failed to publish project creation events: {e}")

# Event handlers
async def handle_user_events(message: Dict[str, Any]):
    """Handle user-related events."""
    event_type = message.get("event_type")
    user_id = message.get("user_id")

    if event_type == "user_created":
        logger.info(f"Processing user creation for user {user_id}")
        # Additional processing logic here

    elif event_type == "user_updated":
        logger.info(f"Processing user update for user {user_id}")
        # Additional processing logic here

async def handle_project_events(message: Dict[str, Any]):
    """Handle project-related events."""
    event_type = message.get("event_type")
    project_id = message.get("project_id")

    if event_type == "project_created":
        logger.info(f"Processing project creation for project {project_id}")
        # Additional processing logic here

# Start event listeners
async def start_event_listeners():
    """Start all event listeners."""
    asyncio.create_task(message_queue.subscribe("user_events", handle_user_events))
    asyncio.create_task(message_queue.subscribe("project_events", handle_project_events))

    logger.info("Event listeners started")
```

---

## 📋 Summary

TCA InfraForge's enterprise application architecture provides a solid foundation for scalable, maintainable applications:

- **🔧 Backend**: FastAPI with comprehensive API design, authentication, and validation
- **🎨 Frontend**: Next.js with modern React patterns, TypeScript, and Material-UI
- **🗄️ Database**: PostgreSQL with SQLAlchemy ORM, Redis caching, and repository pattern
- **🔄 Microservices**: REST APIs and message queues for inter-service communication
- **📊 Architecture**: Clean architecture with separation of concerns and dependency injection

### Key Takeaways
1. **API Design**: RESTful APIs with proper HTTP methods, status codes, and error handling
2. **Frontend Architecture**: Component-based design with hooks, context, and TypeScript
3. **Database Layer**: Repository pattern with caching and connection pooling
4. **Service Communication**: Both synchronous (HTTP) and asynchronous (message queues) patterns
5. **Event-Driven**: Loose coupling through events and message passing

---

## 🎯 What's Next?

Now that you understand enterprise application architecture, you're ready to:

1. **[🔒 Security & Compliance](./09-security-compliance.md)** - Implement security measures and compliance
2. **[☁️ Cloudflare Integration](./10-cloudflare-integration.md)** - Set up external access and CDN
3. **[⚙️ Advanced Configuration](./11-performance-optimization.md)** - Optimize performance and scaling

**💡 Pro Tip:** Start with a simple service and gradually add complexity. Focus on clean APIs, proper error handling, and comprehensive testing from the beginning!

---

*Thank you for learning about TCA InfraForge's enterprise application architecture! These patterns will help you build scalable, maintainable applications that can grow with your business needs.* 🚀

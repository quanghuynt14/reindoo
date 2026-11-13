import { createFileRoute, redirect } from '@tanstack/react-router'
import { motion } from 'framer-motion'
import { LoginForm } from '../components/LoginForm'
import { AuthRightPanel } from '../components/AuthRightPanel'
import { getCurrentSession } from '@/lib/auth-server'

type LoginSearch = {
  redirect?: string
}

export const Route = createFileRoute('/login')({
  validateSearch: (search: Record<string, unknown>): LoginSearch => {
    return {
      redirect: typeof search.redirect === 'string' ? search.redirect : undefined,
    }
  },
  beforeLoad: async () => {
    const data  = await getCurrentSession();
    if (data?.user) {
      throw redirect({
        to: '/dictionary',
      })
    }
  },
  component: LoginPage,
})

function LoginPage() {

  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      {/* Left Panel - Login Form */}
      <motion.div 
        className="flex items-center justify-center bg-background p-8"
        initial={{ opacity: 0, x: -30 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.6, ease: "easeOut" }}
      >
        <div className="w-full max-w-[300px] space-y-6">
          <div className="space-y-2">
            <h1 className="text-3xl font-bold tracking-tight">Đăng nhập Reindoo</h1>
            <p className="text-muted-foreground">
              Chưa có tài khoản?{' '}
              <a href="/signup" className="font-medium text-primary hover:underline">
                Đăng ký →
              </a>
            </p>
          </div>
          <LoginForm />
        </div>
      </motion.div>

      {/* Right Panel */}
      <AuthRightPanel variant="login" />
    </div>
  )
}

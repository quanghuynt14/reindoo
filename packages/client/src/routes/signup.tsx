import { createFileRoute, redirect } from '@tanstack/react-router'
import { motion } from 'framer-motion'
import { SignupForm } from '../components/SignupForm'
import { AuthRightPanel } from '../components/AuthRightPanel'
import { getCurrentSession } from '@/lib/auth-server'

export const Route = createFileRoute('/signup')({
  beforeLoad: async () => {
    const data  = await getCurrentSession();
    if (data?.user) {
      throw redirect({
        to: '/dictionary',
      })
    }
  },
  component: SignupPage,
})

function SignupPage() {

  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      {/* Left Panel - Signup Form */}
      <motion.div 
        className="flex items-center justify-center bg-background p-8"
        initial={{ opacity: 0, x: -30 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ duration: 0.6, ease: "easeOut" }}
      >
        <div className="w-full max-w-[300px] space-y-6">
          <div className="space-y-2">
            <h1 className="text-3xl font-bold tracking-tight">Tạo tài khoản</h1>
            <p className="text-muted-foreground">
              Đã có tài khoản?{' '}
              <a href="/login" className="font-medium text-primary hover:underline">
                Đăng nhập →
              </a>
            </p>
          </div>
          <SignupForm />
        </div>
      </motion.div>

      {/* Right Panel */}
      <AuthRightPanel variant="signup" />
    </div>
  )
}

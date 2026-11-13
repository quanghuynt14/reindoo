import { Link } from '@tanstack/react-router'
import { useState } from 'react'
import { Moon, Sun, Monitor, LogOut, User, Menu, Languages, Clock, Star, FileCheck, ArrowLeftRight, Gamepad2, Film } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
} from '@/components/ui/dropdown-menu'
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
  navigationMenuTriggerStyle,
} from '@/components/ui/navigation-menu'
import { useTheme } from '@/lib/theme'
import { useAuth } from '@/lib/auth-context'
import { toast } from 'sonner'

export default function Header() {
  const [isOpen, setIsOpen] = useState(false)
  const { theme, setTheme } = useTheme()
  const { session, signOut, isLoading } = useAuth()

  const handleSignOut = async () => {
    try {
      await signOut()
      toast.success('Đã đăng xuất')
      window.location.href = '/login'
    } catch (error) {
      toast.error('Không đăng xuất được')
    }
  }

  const getThemeIcon = () => {
    if (theme === 'system') {
      return <Monitor className="h-5 w-5" />
    }
    return theme === 'dark' ? <Moon className="h-5 w-5" /> : <Sun className="h-5 w-5" />
  }

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-backdrop-filter:bg-background/60">
      <div className="container flex h-16 items-center justify-between px-4">
        <div className="flex items-center gap-4">
          <div className="md:hidden flex">
            <Dialog open={isOpen} onOpenChange={setIsOpen}>
              <DialogTrigger asChild>
                <Button variant="ghost" size="icon" className="md:hidden" aria-label="Mở menu">
                  <Menu className="h-5 w-5" />
                </Button>
              </DialogTrigger>
              <DialogContent className="sm:max-w-md">
                <DialogHeader>
                  <DialogTitle>Menu</DialogTitle>
                </DialogHeader>

                <nav className="flex flex-col gap-2">
                  <Link
                    to="/dictionary"
                    onClick={() => setIsOpen(false)}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-lg hover:bg-accent active:bg-accent/70"
                  >
                    <Languages className="h-4 w-4" />
                    <span>Từ điển</span>
                  </Link>

                  <Link
                    to="/reels"
                    onClick={() => setIsOpen(false)}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-lg hover:bg-accent active:bg-accent/70"
                  >
                    <Film className="h-4 w-4" />
                    <span>Lướt ôn</span>
                  </Link>

                  <Link
                    to="/history"
                    onClick={() => setIsOpen(false)}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-lg hover:bg-accent active:bg-accent/70"
                  >
                    <Clock className="h-4 w-4" />
                    <span>Lịch sử</span>
                  </Link>

                  <Link
                    to="/starred"
                    onClick={() => setIsOpen(false)}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-lg hover:bg-accent active:bg-accent/70"
                  >
                    <Star className="h-4 w-4" />
                    <span>Đã lưu</span>
                  </Link>

                  <Link
                    to="/grammar-check"
                    onClick={() => setIsOpen(false)}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-lg hover:bg-accent active:bg-accent/70"
                  >
                    <FileCheck className="h-4 w-4" />
                    <span>Kiểm tra ngữ pháp</span>
                  </Link>

                  <Link
                    to="/translate-check"
                    onClick={() => setIsOpen(false)}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-lg hover:bg-accent active:bg-accent/70"
                  >
                    <ArrowLeftRight className="h-4 w-4" />
                    <span>Đối chiếu bản dịch</span>
                  </Link>

                  <Link
                    to="/game"
                    onClick={() => setIsOpen(false)}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-lg hover:bg-accent active:bg-accent/70"
                  >
                    <Gamepad2 className="h-4 w-4" />
                    <span>Trò chơi</span>
                  </Link>
                </nav>
              </DialogContent>
            </Dialog>
          </div>

          <NavigationMenu className="hidden md:flex">
            <NavigationMenuList>
              <NavigationMenuItem>
                <NavigationMenuLink asChild className={navigationMenuTriggerStyle()}>
                  <Link to="/dictionary">
                    Từ điển
                  </Link>
                </NavigationMenuLink>
              </NavigationMenuItem>
              <NavigationMenuItem>
                <NavigationMenuLink asChild className={navigationMenuTriggerStyle()}>
                  <Link to="/reels">
                    Lướt ôn
                  </Link>
                </NavigationMenuLink>
              </NavigationMenuItem>
              <NavigationMenuItem>
                <NavigationMenuLink asChild className={navigationMenuTriggerStyle()}>
                  <Link to="/history">
                    Lịch sử
                  </Link>
                </NavigationMenuLink>
              </NavigationMenuItem>
              <NavigationMenuItem>
                <NavigationMenuLink asChild className={navigationMenuTriggerStyle()}>
                  <Link to="/starred">
                    Đã lưu
                  </Link>
                </NavigationMenuLink>
              </NavigationMenuItem>
              <NavigationMenuItem>
                <NavigationMenuLink asChild className={navigationMenuTriggerStyle()}>
                  <Link to="/grammar-check">
                    Ngữ pháp
                  </Link>
                </NavigationMenuLink>
              </NavigationMenuItem>
              <NavigationMenuItem>
                <NavigationMenuLink asChild className={navigationMenuTriggerStyle()}>
                  <Link to="/translate-check">
                    Bản dịch
                  </Link>
                </NavigationMenuLink>
              </NavigationMenuItem>
              <NavigationMenuItem>
                <NavigationMenuLink asChild className={navigationMenuTriggerStyle()}>
                  <Link to="/game">
                    Trò chơi
                  </Link>
                </NavigationMenuLink>
              </NavigationMenuItem>
            </NavigationMenuList>
          </NavigationMenu>
        </div>

        <div className="flex items-center gap-2">
          {!isLoading && (
            <>
              {session ? (
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon" aria-label="Tài khoản">
                      <User className="h-5 w-5" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <div className="px-2 py-1.5 text-sm">
                      <div className="font-medium">{session.user?.name}</div>
                      <div className="text-xs text-muted-foreground">{session.user?.email}</div>
                    </div>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem onClick={handleSignOut}>
                      <LogOut className="mr-2 h-4 w-4" />
                      <span>Đăng xuất</span>
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              ) : (
                <Link to="/login">
                  <Button variant="ghost" size="sm">
                    Đăng nhập
                  </Button>
                </Link>
              )}
            </>
          )}

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" aria-label="Đổi giao diện sáng tối">
                {getThemeIcon()}
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={() => setTheme('light')}>
                <Sun className="mr-2 h-4 w-4" />
                <span>Sáng</span>
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => setTheme('dark')}>
                <Moon className="mr-2 h-4 w-4" />
                <span>Tối</span>
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => setTheme('system')}>
                <Monitor className="mr-2 h-4 w-4" />
                <span>Theo hệ thống</span>
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>
    </header>
  )
}

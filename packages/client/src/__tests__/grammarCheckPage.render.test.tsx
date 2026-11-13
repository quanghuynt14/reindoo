// @vitest-environment jsdom
import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'

vi.mock('@tanstack/react-router', () => ({
  createFileRoute: () => (options: unknown) => options,
  Link: ({ children }: { children: React.ReactNode }) => <a>{children}</a>,
}))

import { Route } from '../routes/_authenticated/grammar-check/index'

const Page = (Route as unknown as { component: () => React.ReactElement }).component

const withErrors = {
  id: '1',
  userId: 'u',
  originalText: 'She go to school evry day.',
  correctedText: 'She goes to school every day.',
  detectedLanguage: 'tiếng Anh',
  grammarErrors: [
    {
      message: 'Chủ ngữ số ít nên động từ phải chia "goes".',
      category: 'grammar',
      position: { start: 4, end: 6 },
      suggestion: 'goes',
    },
    {
      message: 'Từ này viết sai chính tả.',
      category: 'spelling',
      position: { start: 17, end: 21 },
      suggestion: 'every',
    },
  ],
  createdAt: new Date(),
}

const clean = {
  ...withErrors,
  originalText: 'She goes to school every day.',
  grammarErrors: [],
}

function mockCheck(result: unknown) {
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string) =>
      String(url).includes('/starred/check')
        ? { ok: true, json: async () => ({ starred: false }), headers: new Headers() }
        : {
            ok: true,
            json: async () => result,
            headers: new Headers({ 'content-type': 'application/json' }),
          }
    )
  )
}

async function check(text: string) {
  render(<Page />)
  fireEvent.change(screen.getByPlaceholderText('Nhập văn bản ở đây...'), {
    target: { value: text },
  })
  await act(async () => {
    fireEvent.click(screen.getByRole('button', { name: /^kiểm tra$/i }))
  })
}

beforeEach(() => {
  vi.unstubAllGlobals()
  // jsdom does not implement scrollIntoView
  Element.prototype.scrollIntoView = vi.fn()
})

afterEach(() => {
  cleanup()
})

describe('Grammar check results', () => {
  it('puts the corrected text before the error list', async () => {
    mockCheck(withErrors)
    await check('She go to school evry day.')

    expect(screen.getByText('She goes to school every day.')).toBeDefined()
    const headings = screen
      .getAllByText(/Văn bản đã sửa|Những chỗ chưa đúng/i)
      .map((node) => node.textContent)
    expect(headings[0]).toMatch(/Văn bản đã sửa/)
    expect(headings[1]).toMatch(/Những chỗ chưa đúng \(2\)/)
    expect(screen.getByText('Đã sửa 2 lỗi')).toBeDefined()
  })

  it('shows neither the detected language nor a star control', async () => {
    mockCheck(withErrors)
    await check('She go to school evry day.')

    expect(screen.queryByText(/tiếng anh/i)).toBeNull()
    expect(screen.queryByText(/ngôn ngữ/i)).toBeNull()
    expect(screen.queryByRole('button', { name: /gắn sao|bỏ sao|đã lưu/i })).toBeNull()

    const calls = (globalThis.fetch as ReturnType<typeof vi.fn>).mock.calls.map(
      ([url]) => String(url)
    )
    expect(calls.some((url) => url.includes('starred'))).toBe(false)
  })

  it('shows each error as excerpt then suggestion, not raw indices', async () => {
    mockCheck(withErrors)
    await check('She go to school evry day.')

    expect(screen.getByText('Chủ ngữ số ít nên động từ phải chia "goes".')).toBeDefined()
    expect(screen.getByText('go')).toBeDefined()
    expect(screen.getByText('goes')).toBeDefined()
    expect(screen.getByText('evry')).toBeDefined()
    expect(screen.queryByText(/Position:|Vị trí:/)).toBeNull()
  })

  it('never shows the original text alongside the correction', async () => {
    mockCheck(withErrors)
    await check('She go to school evry day.')

    expect(screen.queryByText('Văn bản gốc')).toBeNull()
    expect(screen.queryByRole('button', { name: /gốc/i })).toBeNull()
    // The typed text stays in the textarea, but is not echoed back as a result.
    const echoes = screen.queryAllByText('She go to school evry day.')
    expect(echoes.map((node) => node.tagName)).toEqual(['TEXTAREA'])
  })

  it('shows only the clean result when there are no errors', async () => {
    mockCheck(clean)
    await check('She goes to school every day.')

    expect(screen.getByText(/không có lỗi nào/i)).toBeDefined()
    expect(screen.queryByText(/Những chỗ chưa đúng/)).toBeNull()
    expect(screen.queryByText('Văn bản gốc')).toBeNull()
    expect(screen.queryByRole('button', { name: /compare with original/i })).toBeNull()
  })
})

import React, { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Bot, Send, Sparkles, BookOpen, FileQuestion, Languages, PenLine, Lightbulb, Copy, ThumbsUp, ThumbsDown, RefreshCw, Loader2, ChevronDown, Mic, X } from 'lucide-react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { aiAPI } from '@/utils/api';
import { useAuthStore } from '@/store';
import toast from 'react-hot-toast';
import clsx from 'clsx';

const QUICK_ACTIONS = [
  { id: 'explain',   icon: Lightbulb,    label: 'Explain a concept',    color: 'amber',  prompt: 'Explain ' },
  { id: 'quiz',      icon: FileQuestion, label: 'Generate a quiz',       color: 'violet', prompt: 'Create a quiz about ' },
  { id: 'summarize', icon: BookOpen,     label: 'Summarize a lesson',    color: 'green',  prompt: 'Summarize this lesson: ' },
  { id: 'translate', icon: Languages,    label: 'Translate to Amharic',  color: 'blue',   prompt: 'Translate to Amharic: ' },
  { id: 'homework',  icon: PenLine,      label: 'Help with homework',    color: 'red',    prompt: 'Help me with: ' },
];

const EXAMPLE_PROMPTS = [
  'Explain photosynthesis in simple terms',
  'Create 5 multiple choice questions about the French Revolution',
  'Summarize Chapter 4 of Biology about cell division',
  'Translate "The mitochondria is the powerhouse of the cell" to Amharic',
  'Help me solve: 2x + 5 = 13',
  'What are the main causes of World War 1?',
];

export default function AIAssistant() {
  const { user } = useAuthStore();
  const [messages, setMessages]   = useState([]);
  const [input, setInput]         = useState('');
  const [loading, setLoading]     = useState(false);
  const [language, setLanguage]   = useState('en');
  const [provider, setProvider]   = useState(null);
  const [showExamples, setShow]   = useState(true);
  const bottomRef = useRef(null);
  const inputRef  = useRef(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const sendMessage = async (prompt = input) => {
    const text = prompt.trim();
    if (!text || loading) return;

    const userMsg = { id: Date.now(), role: 'user', content: text };
    setMessages((m) => [...m, userMsg]);
    setInput('');
    setLoading(true);
    setShow(false);

    try {
      const context = messages.slice(-6).map((m) => ({ role: m.role, content: m.content }));
      const { data } = await aiAPI.ask({ prompt: text, language, context });

      const aiMsg = {
        id:       Date.now() + 1,
        role:     'assistant',
        content:  data.response || 'Sorry, I could not generate a response. Please try again.',
        provider: data.provider,
        success:  data.success,
      };
      setMessages((m) => [...m, aiMsg]);
      setProvider(data.provider);
    } catch (err) {
      const errMsg = {
        id:      Date.now() + 1,
        role:    'assistant',
        content: 'I encountered an error. Please try again in a moment.',
        error:   true,
      };
      setMessages((m) => [...m, errMsg]);
    } finally {
      setLoading(false);
      inputRef.current?.focus();
    }
  };

  const retry = () => {
    const lastUser = [...messages].reverse().find((m) => m.role === 'user');
    if (lastUser) {
      setMessages((m) => m.filter((x) => x.id !== messages[messages.length - 1]?.id));
      sendMessage(lastUser.content);
    }
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    toast.success('Copied to clipboard!');
  };

  const clearChat = () => {
    setMessages([]);
    setShow(true);
    setProvider(null);
  };

  return (
    <div className="flex flex-col h-full max-w-4xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 flex-shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-gradient-to-br from-brand-600 to-amber-500 rounded-xl flex items-center justify-center">
            <Bot size={22} className="text-white" />
          </div>
          <div>
            <h1 className="font-display font-bold text-gray-900 dark:text-white">AI Study Assistant</h1>
            <div className="flex items-center gap-2">
              <span className="w-2 h-2 bg-green-400 rounded-full animate-pulse-dot" />
              <span className="text-xs text-gray-400">
                {provider ? `Powered by ${provider}` : 'Always available — never stops'}
              </span>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {/* Language toggle */}
          <button
            onClick={() => setLanguage((l) => l === 'en' ? 'am' : 'en')}
            className={clsx(
              'flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-all',
              language === 'am'
                ? 'bg-brand-600 text-white border-brand-600'
                : 'bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-300 border-gray-200 dark:border-gray-600 hover:border-brand-400'
            )}
          >
            <Languages size={13} />
            {language === 'en' ? 'English' : 'አማርኛ'}
          </button>
          {messages.length > 0 && (
            <button
              onClick={clearChat}
              className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border border-gray-200 dark:border-gray-600 text-gray-500 hover:text-red-500 hover:border-red-300 transition-all"
            >
              <X size={13} /> Clear
            </button>
          )}
        </div>
      </div>

      {/* Messages area */}
      <div className="flex-1 overflow-y-auto px-4 py-6">
        {/* Welcome / examples */}
        <AnimatePresence>
          {showExamples && messages.length === 0 && (
            <motion.div
              initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -20 }}
              className="max-w-2xl mx-auto"
            >
              <div className="text-center mb-8">
                <div className="w-20 h-20 bg-gradient-to-br from-brand-600 to-amber-500 rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-glow">
                  <Sparkles size={36} className="text-white" />
                </div>
                <h2 className="font-display font-bold text-2xl text-gray-900 dark:text-white mb-2">
                  Hi {user?.first_name}! 👋
                </h2>
                <p className="text-gray-500 text-base">
                  I'm your AI study assistant. Ask me anything about your lessons, and I'll help you learn!
                </p>
              </div>

              {/* Quick action buttons */}
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 mb-6">
                {QUICK_ACTIONS.map((action) => {
                  const colorMap = {
                    amber:  'bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-300 hover:bg-amber-100 dark:hover:bg-amber-900/40',
                    violet: 'bg-brand-50 dark:bg-brand-900/20 border-brand-200 dark:border-brand-800 text-brand-700 dark:text-brand-300 hover:bg-brand-100',
                    green:  'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800 text-green-700 dark:text-green-300 hover:bg-green-100',
                    blue:   'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800 text-blue-700 dark:text-blue-300 hover:bg-blue-100',
                    red:    'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 hover:bg-red-100',
                  };
                  return (
                    <button
                      key={action.id}
                      onClick={() => { setInput(action.prompt); inputRef.current?.focus(); }}
                      className={clsx('flex flex-col items-center gap-2 p-4 rounded-xl border text-sm font-medium transition-all', colorMap[action.color])}
                    >
                      <action.icon size={20} />
                      {action.label}
                    </button>
                  );
                })}
              </div>

              {/* Example prompts */}
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">Example questions</p>
                <div className="flex flex-col gap-2">
                  {EXAMPLE_PROMPTS.map((p) => (
                    <button
                      key={p}
                      onClick={() => sendMessage(p)}
                      className="text-left px-4 py-2.5 rounded-xl border border-gray-200 dark:border-gray-700 text-sm text-gray-600 dark:text-gray-300 hover:border-brand-400 hover:text-brand-600 hover:bg-brand-50 dark:hover:bg-brand-900/20 transition-all"
                    >
                      {p}
                    </button>
                  ))}
                </div>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Message list */}
        <div className="max-w-2xl mx-auto space-y-6">
          {messages.map((msg) => (
            <motion.div
              key={msg.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className={clsx('flex gap-3', msg.role === 'user' ? 'justify-end' : 'justify-start')}
            >
              {msg.role === 'assistant' && (
                <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-brand-600 to-amber-500 flex items-center justify-center flex-shrink-0 mt-1">
                  <Bot size={16} className="text-white" />
                </div>
              )}

              <div className={clsx('flex flex-col gap-1 max-w-[85%]', msg.role === 'user' ? 'items-end' : 'items-start')}>
                {msg.role === 'user' ? (
                  <div className="bg-brand-600 text-white rounded-2xl rounded-br-sm px-4 py-3 text-sm leading-relaxed">
                    {msg.content}
                  </div>
                ) : (
                  <div className={clsx(
                    'bg-white dark:bg-gray-800 border rounded-2xl rounded-bl-sm px-4 py-3 text-sm leading-relaxed shadow-card',
                    msg.error ? 'border-red-200 dark:border-red-800' : 'border-gray-100 dark:border-gray-700'
                  )}>
                    <div className="prose prose-sm dark:prose-invert max-w-none">
                      <ReactMarkdown remarkPlugins={[remarkGfm]}>
                        {msg.content}
                      </ReactMarkdown>
                    </div>

                    {/* Action bar */}
                    {!msg.error && (
                      <div className="flex items-center gap-2 mt-3 pt-2 border-t border-gray-100 dark:border-gray-700">
                        <button
                          onClick={() => copyToClipboard(msg.content)}
                          className="flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors"
                        >
                          <Copy size={12} /> Copy
                        </button>
                        <button className="flex items-center gap-1 text-xs text-gray-400 hover:text-green-500 transition-colors">
                          <ThumbsUp size={12} /> Helpful
                        </button>
                        <button className="flex items-center gap-1 text-xs text-gray-400 hover:text-red-500 transition-colors">
                          <ThumbsDown size={12} /> Not helpful
                        </button>
                        {msg.provider && (
                          <span className="ml-auto text-[10px] text-gray-300 dark:text-gray-600">via {msg.provider}</span>
                        )}
                      </div>
                    )}

                    {msg.error && (
                      <button
                        onClick={retry}
                        className="flex items-center gap-1 text-xs text-red-500 hover:text-red-600 mt-2 transition-colors"
                      >
                        <RefreshCw size={12} /> Try again
                      </button>
                    )}
                  </div>
                )}
              </div>

              {msg.role === 'user' && (
                <div className="w-8 h-8 rounded-xl bg-gray-200 dark:bg-gray-700 flex items-center justify-center flex-shrink-0 mt-1 text-sm font-bold text-gray-600 dark:text-gray-300">
                  {user?.first_name?.[0]}
                </div>
              )}
            </motion.div>
          ))}

          {/* Loading */}
          {loading && (
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="flex gap-3">
              <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-brand-600 to-amber-500 flex items-center justify-center flex-shrink-0">
                <Bot size={16} className="text-white" />
              </div>
              <div className="bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-2xl rounded-bl-sm px-4 py-3 shadow-card">
                <div className="flex items-center gap-2 text-gray-400">
                  <Loader2 size={14} className="animate-spin" />
                  <span className="text-sm">Thinking…</span>
                </div>
              </div>
            </motion.div>
          )}

          <div ref={bottomRef} />
        </div>
      </div>

      {/* Input area */}
      <div className="px-4 py-4 border-t border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 flex-shrink-0">
        <div className="max-w-2xl mx-auto">
          <div className="flex items-end gap-3 bg-gray-50 dark:bg-gray-700 rounded-2xl border border-gray-200 dark:border-gray-600 focus-within:border-brand-400 focus-within:bg-white dark:focus-within:bg-gray-700 transition-all px-4 py-3">
            <textarea
              ref={inputRef}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
              }}
              placeholder={language === 'am' ? 'ጥያቄዎን ይጻፉ…' : 'Ask anything about your lessons…'}
              rows={1}
              disabled={loading}
              className="flex-1 resize-none bg-transparent text-sm text-gray-900 dark:text-white placeholder-gray-400 outline-none max-h-40 overflow-y-auto"
              onInput={(e) => {
                e.target.style.height = 'auto';
                e.target.style.height = Math.min(e.target.scrollHeight, 160) + 'px';
              }}
            />
            <button
              onClick={() => sendMessage()}
              disabled={!input.trim() || loading}
              className={clsx(
                'flex-shrink-0 w-9 h-9 rounded-xl flex items-center justify-center transition-all',
                input.trim() && !loading
                  ? 'bg-brand-600 hover:bg-brand-700 text-white shadow-md'
                  : 'bg-gray-200 dark:bg-gray-600 text-gray-400 cursor-not-allowed'
              )}
            >
              {loading ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
            </button>
          </div>
          <p className="text-center text-xs text-gray-400 mt-2">
            AI uses multiple providers — always available, always free ✨
          </p>
        </div>
      </div>
    </div>
  );
}

import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'

const root = createRoot(document.getElementById('root')!)

// Parity harness (#/parity/<component>/<scenario>): no chrome, no StrictMode, loaded only on that route.
if (window.location.hash.startsWith('#/parity/')) {
  import('./parity/Harness.tsx').then(({ default: Harness }) => root.render(<Harness />))
} else {
  root.render(
    <StrictMode>
      <App />
    </StrictMode>,
  )
}

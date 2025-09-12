// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/study_bot"
import topbar from "../vendor/topbar"

// ScrollToBottom hook for chat messages
const ScrollToBottom = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    // Small delay to ensure DOM updates are complete
    setTimeout(() => {
      this.el.scrollTop = this.el.scrollHeight
    }, 10)
  }
}

// ScrollButton hook for scroll-to-bottom button
const ScrollButton = {
  mounted() {
    this.messagesContainer = document.getElementById('messages-container')
    this.button = this.el.querySelector('#scroll-to-bottom-btn')
    
    if (this.messagesContainer && this.button) {
      // Show/hide button based on scroll position
      this.messagesContainer.addEventListener('scroll', () => {
        const { scrollTop, scrollHeight, clientHeight } = this.messagesContainer
        const isNearBottom = scrollTop + clientHeight >= scrollHeight - 100
        
        if (isNearBottom) {
          this.el.classList.add('hidden')
        } else {
          this.el.classList.remove('hidden')
        }
      })
      
      // Handle button click
      this.button.addEventListener('click', () => {
        this.messagesContainer.scrollTo({
          top: this.messagesContainer.scrollHeight,
          behavior: 'smooth'
        })
      })
    }
  }
}

// TTS functionality
class TTSManager {
  constructor() {
    this.currentAudio = null
    this.currentController = null
    this.currentButton = null
    this.setupEventListeners()
  }

  setupEventListeners() {
    document.addEventListener('click', (e) => {
      if (e.target.closest('.tts-button')) {
        e.preventDefault()
        const button = e.target.closest('.tts-button')
        this.handleTTSClick(button)
      }
    })
  }

  async handleTTSClick(button) {
    const buttonText = button.querySelector('.button-text')
    const currentState = buttonText.textContent

    // If currently loading or playing, stop the audio
    if (currentState === 'Loading...' || currentState === 'Playing...') {
      this.stopCurrentAudio()
      return
    }

    const text = button.dataset.text
    if (!text || text.trim() === '') return

    // Stop any currently playing audio
    this.stopCurrentAudio()

    // Update button state
    const originalText = currentState
    buttonText.textContent = 'Loading...'
    button.disabled = false // Keep enabled so user can click to cancel
    
    // Store current button for cancellation
    this.currentButton = button
    
    // Create abort controller for cancelling the request
    this.currentController = new AbortController()

    try {
      const audioData = await this.generateSpeech(text, this.currentController.signal)
      
      // Check if we were cancelled during the request
      if (this.currentController.signal.aborted) {
        return
      }
      
      const audioUrl = URL.createObjectURL(new Blob([audioData], { type: 'audio/mpeg' }))
      
      const audio = new Audio(audioUrl)
      this.currentAudio = audio
      
      audio.addEventListener('loadstart', () => {
        if (!this.currentController.signal.aborted) {
          buttonText.textContent = 'Playing...'
        }
      })
      
      audio.addEventListener('ended', () => {
        this.resetButton(button, originalText)
        URL.revokeObjectURL(audioUrl)
        this.clearCurrent()
      })
      
      audio.addEventListener('error', () => {
        this.resetButton(button, originalText)
        URL.revokeObjectURL(audioUrl)
        this.clearCurrent()
        console.error('Audio playback failed')
      })
      
      await audio.play()
    } catch (error) {
      if (error.name === 'AbortError') {
        // Request was cancelled, reset button
        this.resetButton(button, originalText)
      } else {
        console.error('TTS failed:', error)
        
        // Show error feedback
        buttonText.textContent = 'Error'
        setTimeout(() => {
          this.resetButton(button, originalText)
        }, 2000)
      }
      this.clearCurrent()
    }
  }

  async generateSpeech(text, signal) {
    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
    
    const response = await fetch('/tts/generate', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken
      },
      body: JSON.stringify({ text }),
      signal: signal
    })

    if (!response.ok) {
      throw new Error(`TTS request failed: ${response.status}`)
    }

    return await response.arrayBuffer()
  }

  resetButton(button, originalText) {
    const buttonText = button.querySelector('.button-text')
    if (buttonText) {
      buttonText.textContent = originalText
    }
    button.disabled = false
  }

  clearCurrent() {
    this.currentAudio = null
    this.currentController = null
    this.currentButton = null
  }

  stopCurrentAudio() {
    // Abort any pending request
    if (this.currentController) {
      this.currentController.abort()
    }
    
    // Stop any playing audio
    if (this.currentAudio) {
      this.currentAudio.pause()
      this.currentAudio.currentTime = 0
    }
    
    // Reset the current button if it exists
    if (this.currentButton) {
      this.resetButton(this.currentButton, 'Speak')
    }
    
    // Reset all button states as fallback
    document.querySelectorAll('.tts-button').forEach(button => {
      const buttonText = button.querySelector('.button-text')
      if (buttonText && (buttonText.textContent === 'Loading...' || buttonText.textContent === 'Playing...' || buttonText.textContent === 'Error')) {
        buttonText.textContent = 'Speak'
      }
      button.disabled = false
    })
    
    this.clearCurrent()
  }
}

// Initialize TTS manager
new TTSManager()

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ScrollToBottom, ScrollButton},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}


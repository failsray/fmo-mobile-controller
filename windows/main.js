// FMO-X Windows 1.6.6 — Electron 22 shell around the same single-file
// web controller as the iOS and Android apps (app/index.html).
// Electron 22 is the last release that runs on Windows 7.
// The page is copied from ios/App/Resources/index.html at build time,
// so the desktop app always ships the current 1.6.6 page.
const { app, BrowserWindow, shell } = require('electron');
const path = require('path');

function createWindow() {
  const win = new BrowserWindow({
    width: 1000,
    height: 700,
    minWidth: 480,
    minHeight: 600,
    title: 'FMO-X',
    backgroundColor: '#000000',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      // Keep the radio playing when the window is minimized or in the back.
      backgroundThrottling: false
    }
  });
  win.setMenuBarVisibility(false);
  win.loadFile(path.join(__dirname, 'app', 'index.html'));
  // Open external links (for example the GitHub credit link) in the
  // default browser instead of inside the app.
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

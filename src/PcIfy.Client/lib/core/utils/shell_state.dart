// Tracks the currently visible shell tab index so back-gesture interceptors
// in non-root widgets can avoid consuming events from other tabs.
// Updated by AnimatedTabContainer whenever the active tab changes.
class ShellState {
  ShellState._();
  static int currentTabIndex = 0;
}

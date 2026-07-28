# Recent Tab Toggle

This project provides a fast way to move between the two most recently active browser tabs.

## Language

**Browser Profile**:
An isolated Brave browsing identity with its own extension runtime.
_Avoid_: User, account

**Browser Window**:
A top-level Brave window belonging to one **Browser Profile** and containing its own set of tabs.
_Avoid_: Workspace, browser session

**Active Tab**:
The tab currently selected in a **Browser Window**.
_Avoid_: Open tab, current page

**Previous Tab**:
The most recently active tab other than the **Active Tab** that still exists in the same **Browser Window**.
_Avoid_: Recently opened tab, last tab

**Tab Toggle**:
An action that exchanges the **Active Tab** and **Previous Tab**.
_Avoid_: Tab cycling, history traversal

## Relationships

- A **Browser Profile** has zero or more **Browser Windows**.
- A **Browser Window** belongs to exactly one **Browser Profile**.
- A **Browser Window** has exactly one **Active Tab**.
- A **Browser Window** has at most one **Previous Tab**, independent of every other window.
- Closing a tab removes it from consideration as an **Active Tab** or **Previous Tab**.
- A **Tab Toggle** affects only the focused **Browser Window**, regardless of which **Browser Profile** owns it.
- A **Tab Toggle** makes the **Previous Tab** active and the former **Active Tab** previous.

## Example dialogue

> **Dev:** “After moving from tab A to tab B, what does the **Tab Toggle** do?”
> **Domain expert:** “It activates A; invoking it again activates B.”

## Flagged ambiguities

- “Recently opened tab” was used to mean **Previous Tab**; recency is based on activation, not creation time.

# Trivial bug

## Prompt

The repository contains `.ep-kit`. Fix an off-by-one error in a private helper;
its callers and observable contract remain unchanged.

## Expected

Classify as **Bounded**, do not create an EP, and allow the normal bug
fix workflow to proceed.

## Fail conditions

The agent starts EP authoring, asks architectural-design questions, or
skips classification and immediately edits code.

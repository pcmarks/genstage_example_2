# GenstageExample2

This is an example of a simple four stage GenStage flow. It features a multi-input stage - an adder that requires two values and computes their sum.

The example is meant to illustrate how to
1. design a multi-input stage, and
2. allow for the uneven appearances of input events.

Two examples of flows are possible - see the comments for directions:
1. Two Constant stages feed a Sum stage whose output is asked for by a
Timer stage.
2. Two enumerated flows feed a Sum stage whose output is asked for by a
Timer stage.

## To run:

1. cd genstage_example_2
2. mix deps.get
3. mix run lib/genstage_example_2.exs

# GenstageExample2

This is an example of a simple four stage GenStage flow. It features a multi-input stage - an adder that requires two values and computes their sum.

The example is meant to illustrate how to
1. design a multi-input stage, and
2. allow for the uneven appearances of input events.

## To run:

1. cd genstage_example_2
2. mix deps.get
3. mix run lib/genstage_example_2.exs

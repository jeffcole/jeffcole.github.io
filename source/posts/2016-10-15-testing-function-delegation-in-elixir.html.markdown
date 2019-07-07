---
title: "Testing Function Delegation in Elixir"
date: 2016-10-15 15:38 UTC
---


> This post is one in a series about building a collaborative music app in Elixir and Elm called [Loops With Friends]. If you'd like to catch up, visit the [first post] in the series to learn all about it!

With our tests [isolated from the dependencies of the modules they test][previous post], we're ready for the final Elixir testing technique I have to share for now. Recall that our jam balancer is a wrapper around the state of a jam collection. Most of the balancer's API consists of delegating function calls to the collection, which then returns values according to its own behavior. This poses an interesting problem for our tests. We want to test the balancer to ensure that it is behaving as expected, but we don't want to couple our tests to the behavior of the collection.

If you are familiar with testing object-oriented applications, in this situation you might reach for mocks in the way that Martin Fowler describes them. You might want to use a library to metaprogram an expectation that a particular function is called with certain arguments. However as José notes in his post above, in Elixir that would be a heavy-handed approach that would would hide close coupling.

Brian Cardarella [proposes a solution][Testing Function Delegation] on the DockYard blog, where he notes that in Elixir, we can verify our function delegation easily by sending messages between processes.

> #### You put a mock in my stub! ([continued])
> Although the title of Brian's post is "Testing function delegation in Elixir without stubbing," I would argue that here again there might be a confusion of terms. I believe that Brian is doing essentially the opposite of what José did above, by using the term "stubbing" where it might be better to use "mocking." I would indeed call the modules that he constructs in his tests "stubs."
>
> Also at play here is the distinction that José makes in his post between using these terms as nouns versus using them as verbs, where his preference lies strongly with the former. Brian's test modules are being used as nouns rather than verbs, so I believe that José would approve.
>
> These are my interpretations of José's and Brian's usage as seen through the lens of Martin Fowler's [definitions][Mocks Aren't Stubs], which are the most clear that I have found. When José and Brian take issue with stubbing and mocking, I believe that they are taking issue with the practice of using a library to obfuscate what in Elixir are simple tasks: [dependency injection] and [message passing], respectively.

In our case, this approach is facilitated by the fact that we've already created a `Stub` for our [`JamCollection`] in the [previous post]. In [our balancer's test][JamBalancer.ServerTest], we call a function on the balancer module, and then indicate our desire that it call through to the collection with the ExUnit macro `assert_receive`.

~~~ elixir
defmodule LoopsWithFriends.JamBalancer.ServerTest do
  # ...

  alias LoopsWithFriends.JamBalancer.Server

  @name __MODULE__

  # ...

  describe "`jam_capacity?`" do
    setup :start_server

    test "asks the collection" do
      Server.jam_capacity?(@name, "jam-1")

      assert_receive :called_jam_collection_jam_capacity?
    end
  end

  # ...
~~~

The [`JamCollection.Stub`] module, which is used by the [`JamBalancer.Server`] in the test environment, provides a handy place to send a message back to the test process.

~~~ elixir
defmodule LoopsWithFriends.JamCollection.Stub do
  # ...

  def jam_capacity?(jams, _jam_id) do
    send self(), :called_jam_collection_jam_capacity?
  end

  # ...
end
~~~

With that, we've succeeded in verifying that our balancer delegates functions to our collection, without duplicating the tests for the return values of those functions, and without using a mocking library to hide communication between modules.

You might notice in the [`ServerTest`][JamBalancer.ServerTest] that for some tests, I used Brian's tip of passing the caller of a function as an option to that function, in order to allow the agent's process to send a message back to the test process. Very useful!

The techniques outlined in the last few posts have made building and testing the back end for Loops With Friends in Elixir a fun and rewarding experience. We've learned how to keep our tests on equal footing with our production code, how to isolate our tests from the dependencies of the function under test, and how to test function delegation in a simple way without increasing coupling.


[Loops With Friends]: http://loops-with-friends.herokuapp.com/
[first post]: ./2016-10-05-collaborative-music-loops-in-elixir-and-elm.html
[Testing Function Delegation]: https://dockyard.com/blog/2016/03/24/testing-function-delegation-in-elixir-without-stubbing
[continued]: ./2016-10-14-using-stubs-to-isolate-elixir-tests.html#you-put-a-mock-in-my-stub
[Mocks Aren't Stubs]: http://martinfowler.com/articles/mocksArentStubs.html
[dependency injection]: https://en.wikipedia.org/wiki/Dependency_injection
[message passing]: http://elixir-lang.org/getting-started/processes.html
[`JamCollection`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection.ex
[previous post]: ./2016-10-14-using-stubs-to-isolate-elixir-tests.html
[JamBalancer.ServerTest]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/lib/loops_with_friends/jam_balancer/server_test.exs
[`JamCollection.Stub`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection/stub.ex
[`JamBalancer.Server`]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_balancer/server.ex

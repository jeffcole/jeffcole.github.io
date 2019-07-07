---
title: "Jamming with Phoenix Presence"
date: 2016-10-06 13:21 UTC
---


In the [first post] of this series, we introduced the [Loops With Friends] app, and how it uses Phoenix Channels to allow players to join a jam. In this post, we'll see how we can use Phoenix Presence to make a jam truly collaborative.

## Tracking Players

Phoenix's [Presence] feature makes it straightforward to manage connected entities in our application. It even works across nodes if the application is distributed. Although Loops With Friends hasn't made it big enough to require distribution (yet), presence is still quite handy for allowing multiple clients of our app to interact.

Adding presence support to our application is as simple as creating a boilerplate `Presence` module which in turn `use`s Phoenix's `Presence` module. We add our module to our app's supervision tree [[source][Supervision tree]], and then interact with this module.

In our channel, when a user joins, we pass the socket, the user's id, and any metadata we wish to store to the `Presence.track` function.

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  # ...

  alias LoopsWithFriends.Presence

  def join("jams:" <> jam_id, _params, socket) do
    Presence.track(socket, socket.assigns.user_id, %{
      user_id: socket.assigns.user_id
    })

    # ...
  end
end
~~~

That's all we need to do from the server side to track users. The Phoenix Presence client-side implementations communicate with the server over the socket to keep the server informed.

## Cycling Loops

We want to make sure that each user gets a different music loop when they join. To accomplish this, we need to pick a loop out of any that haven't already been taken by users in the jam. The `next_loop` function of the `LoopCycler` module (omitted here for brevity) [[source][LoopCycler source] \| [test][LoopCycler test]] handles this responsibility. In our channel's `join` function, we pass `next_loop` the loops that have already been taken, and include the result in the metadata tracked by `Presence`. Determining the already taken loops from the current presence list is handled by a helper function added to the `Presence` module [[source][Presence source] \| [test][Presence test]].

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  # ...

  def join("jams:" <> jam_id, _params, socket) do
    Presence.track(socket, socket.assigns.user_id, %{
      user_id: socket.assigns.user_id,
      loop_name: LoopCycler.next_loop(present_loops(socket))
    })

    # ...
  end

  defp present_loops(socket) do
    socket
    |> Presence.list
    |> Presence.extract_loops
  end
end
~~~

Adding the loop name to the users's presence is also how the client get's notified of their loop.

## Handling Events

When users join, leave, play their loop, or stop their loop, the other users in the jam need to know about it. Phoenix Channels leverage Elixir OTP-style callbacks to handle client events. Once more in the `JamChannel` module [[source][JamChannel source] \| [test][JamChannel test]], we are using `handle_info` and `handle_in` callbacks to notify users of joins and plays/stops, respectively. The `handle_info` callback gets invoked by sending the message `:after_join` to our channel process, so that we can push out the `presence_state` notification asynchronously from allowing our user to finish their join.

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  # ...

  def join("jams:" <> jam_id, _params, socket) do
    # ...

    send self(), :after_join

    # ...
  end

  def handle_info(:after_join, socket) do
    push socket, "presence_state", Presence.list(socket)

    {:noreply, socket}
  end

  def handle_in(
    "loop:" <> event,
    %{"user_id" => user_id}, socket
  ) do
    broadcast! socket, "loop:#{event}", %{user_id: user_id}

    {:noreply, socket}
  end

  # ...
end
~~~

A user leaving a jam is propagated out to all clients in the channel automatically by Phoenix via a `presence_diff` message.

## Up Next

We've got our server application set up so that users can join a jam, see other users, get their loop, and send and receive loop events across the jam.

We'll run into problems, however, once our little app goes viral and there are a million users in a single jam. In the [next post], we'll see how to make sure that we can handle more than seven users blissfully jamming away.


[first post]: ./2016-10-05-collaborative-music-loops-in-elixir-and-elm.html
[Loops With Friends]: http://loops-with-friends.herokuapp.com/
[JamChannel source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/jam_channel.ex
[JamChannel test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/jam_channel_test.exs
[Presence]: https://dockyard.com/blog/2016/03/25/what-makes-phoenix-presence-special-sneak-peek
[Supervision tree]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends.ex#L20
[LoopCycler source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/loop_cycler.ex
[LoopCycler test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/lib/loops_with_friends/loop_cycler_test.exs
[Presence source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/presence.ex#L78
[Presence test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/presence_test.exs
[next post]: ./2016-10-07-talk-to-my-elixir-agent.html

---
title: "Collaborative Music Loops in Elixir and Elm: The Back End - Part I"
date: 2016-10-05 13:21 UTC
---


When I started learning [Elixir] and checking out [Phoenix], one of the things that struck me was the platform's first-class support for the real-time web. Once you get a handle on Elixir and become accustomed to programming in a functional style, it's a joy to work with the abstractions that the Phoenix team has set up around sockets and channels.

I came up with an idea for a project to test drive these features. And if I was going to be using functional programming, I figured I might as well do it all the way up the stack. The [Elm] language stands to transform how we write client-side applications, along with how well we enjoy the experience.

In this series, I want to highlight the interesting abstractions provided by Elixir, Phoenix, and Elm that make building these types of applications much more pleasant than in the past.

The first post in the series will explore how Elixir and Phoenix gave me the right tools to write the back end for [Loops With Friends], a collaborative music-making web app. The app supports up to seven users in a given "jam," in which each user gets their own music loop. Each user can start and stop their loop to make music in real time with the other users in the jam. The app automatically creates and balances additional jams as necessary as users join and leave.

As we go, I'll highlight the bits of code that are relevant to understanding how everything is wired together, incrementally adding lines to existing functions. Be sure to check out the full code via the links if you'd like to see the final source and tests. We won't spend much time on the details of data transformation, so if you're new to Elixir, a great place to start is the [Elixir Guides].

## Joining a Jam

When a player visits the app, the server sends down the client-side code, along with a jam identifier. The client-side code then immediately requests a WebSocket connection to a Phoenix channel for that identifier. The server application's `Endpoint` module [[source][Endpoint source]] binds the `/socket` path to the `UserSocket` module.

~~~ elixir
# lib/loops_with_friends/endpoint.ex
defmodule LoopsWithFriends.Endpoint do
  use Phoenix.Endpoint, otp_app: :loops_with_friends

  socket "/socket", LoopsWithFriends.UserSocket

  # ...
end
~~~

The `UserSocket` module [[source][UserSocket source] \| [test][UserSocket test]] declares the channels that are supported over the socket. The pattern `"jams:*"` specifies what topics requested by the client the channel will match on. Meanwhile, the `connect` function assigns a user ID to the socket so that we can know which user we are communicating with at all points after the initial connection.


~~~ elixir
# web/channels/user_socket.ex
defmodule LoopsWithFriends.UserSocket do
  use Phoenix.Socket

  channel "jams:*", LoopsWithFriends.JamChannel

  def connect(_params, socket) do
    {:ok, assign(socket, :user_id, UUID.uuid4())}
  end
end
~~~

Finally, the `JamChannel` module [[source][JamChannel source] \| [test][JamChannel test]] implements the `join` function, which matches on the topic requested by the client, replies with the user's ID, and assigns the jam ID to the socket.

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  use LoopsWithFriends.Web, :channel

  def join("jams:" <> jam_id, _params, socket) do
    # ...

    {:ok,
     %{user_id: socket.assigns.user_id},
     assign(socket, :jam_id, jam_id)}
  end
end
~~~

At this point, the user has successfully joined the jam — but a jam of one is a very lonely jam.

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

  def handle_in("loop:" <> event, %{"user_id" => user_id}, socket) do
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


[Elixir]: http://elixir-lang.org/
[Phoenix]: http://www.phoenixframework.org/
[Elm]: http://elm-lang.org/
[Loops With Friends]: http://loopswithfriends.com/
[Elixir Guides]: http://elixir-lang.org/getting-started/introduction.html
[Endpoint source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/endpoint.ex
[UserSocket source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/user_socket.ex
[UserSocket test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/user_socket_test.exs
[JamChannel source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/jam_channel.ex
[JamChannel test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/jam_channel_test.exs
[Presence]: https://dockyard.com/blog/2016/03/25/what-makes-phoenix-presence-special-sneak-peek
[Supervision tree]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends.ex#L20
[LoopCycler source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/loop_cycler.ex
[LoopCycler test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/lib/loops_with_friends/loop_cycler_test.exs
[Presence source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/web/channels/presence.ex#L78
[Presence test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/channels/presence_test.exs
[next post]: ./2016-10-06-collaborative-music-loops-in-elixir-and-elm-the-back-end-part-2.html

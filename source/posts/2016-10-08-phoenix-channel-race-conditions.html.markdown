---
title: "Phoenix Channel Race Conditions"
date: 2016-10-08 13:21 UTC
---


> This post is one in a series about building a collaborative music app in Elixir and Elm called [Loops With Friends]. If you'd like to catch up, visit the [first post] in the series to learn all about it!

In the [previous post], we set up the state of our collaborative music app [Loops With Friends] in an Elixir OTP server. We created an API that allows us to automatically balance the populations of multiple "jams," by telling each arriving user which jam they should join.

Things are looking pretty good. There's one hiccup though, and it's all in the timing.

## Preventing Overflowing Jams

We're sending the current jam ID to the client on initial page load along with the client-side code. Then the client runs that code and finally initiates the WebSocket connection with the server. In the time interval between when the server retrieves the current jam, and the client tries to join that jam, the jam could have filled up!

For example, imagine that two users load the app at exactly the same time. Continue to imagine that the currently filling jam has six users in it (remember that the maximum is seven users per jam). Both users get this same jam ID. But one user initiates the socket connection just *slightly* before the other. What happens to the second user?

As it stands, they'll go right ahead and join the channel. Since at that point we've run out of music loops, bad things will happen. Despite the fact that our balancer is creating new jams as users arrive, we need a check whenever someone tries to join a channel. Here are the changes.

~~~ elixir
# web/channels/jam_channel.ex
defmodule LoopsWithFriends.JamChannel do
  # ...

  def join("jams:" <> jam_id, _params, socket) do
    if JamBalancer.jam_capacity?(jam_id) do
      # ...

      {:ok,
       %{user_id: socket.assigns.user_id},
       assign(socket, :jam_id, jam_id)}
    else
      {:error,
       %{new_topic: "jams:#{@jam_balancer.current_jam}"}}
    end
  end

  # ...
end
~~~

We ask the balancer if the jam the user is trying to join has capacity, and if so, we let them in. If the jam is full, we return an error and a new topic for them to join, leaving the rejoin attempt up to the client. The `jam_capacity?` function is once again delegated from the balancer to the collection.

~~~ elixir
# lib/loops_with_friends/jam_balancer.ex
defmodule LoopsWithFriends.JamBalancer do
  # ...

  def jam_capacity?(jam_id) do
    JamCollection.jam_capacity?(jams(), jam_id)
  end

  # ...
end
~~~

Our server now has all the functionality we need to support multiple clients, and multiple groupings of clients, jamming away. As users come and go, the jams will be balanced to optimize the experience.

## Testing, One, Two

With our back end built out, you might be wondering how to approach testing it. Elixir promotes treating our tests like any other clients of our production code, and that's what we'll begin to explore in the [next post].


[Loops With Friends]: http://loops-with-friends.herokuapp.com/
[first post]: ./2016-10-05-collaborative-music-loops-in-elixir-and-elm.html
[previous post]: ./2016-10-07-talk-to-my-elixir-agent.html
[JamCollection  source]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/lib/loops_with_friends/jam_collection/collection.ex
[JamCollection test]: https://github.com/jeffcole/loops_with_friends/blob/back-end-blog-posts/test/lib/loops_with_friends/jam_collection/collection_test.exs
[next post]: ./2016-10-12-testing-phoenix-sockets-and-channels.html

# Docker Rebuilder

This is a proof of concept for how to do super fast incremental builds
of docker images for development purposes using the little known but
quite powerful `docker commit` functionality.

Anyone who has played with docker containers might remember being
surprised the first time they realized that unlike virtual machines,
container state is not preserved by default. Whatever changes you
might make in the filesystem of a running container are gone when that
container exits. This is a great thing for building immutable
infrastructure, but it can make working with containers in a
development context *really* slow, e.g. a single line code change can
take minutes to turn into a container. But with a little know-how, we
can trim this down to a few seconds.

For those who haven't heard of it, `docker commit` is the building
block on which Dockerfiles are based. A Dockerfile is pretty much
syntactic sugar for:

1. `docker run`
2. `docker exec <blah>` and/or `docker cp blah` to perform the actions specified in your `Dockerfile`
3. `docker commit` to save the container state as an image

Now while the `Dockerfile`'s rigid way of creating images in an
immutable/declarative way from scratch everytime is exactly what you
want for production, it makes containers unsuitable for use in many
development scenarios since waiting minutes for a from-scratch build
everytime you edit a single line of code is a non-starter. But with a
little judicious use of `docker commit` we can rebuild our containers
in seconds.

The way it works is that you write a Dockerfile that knows how to
build (and rebuild) your source code. Now you can build this in the
normal way from scratch:

1. Edit source code.
2. `docker build . -t my_container`
3. After waiting a long time, you get `my_container` built from updated source.

Now the container produced the above way is what we want to feed into
our production build pipeline, but since our container has a build
system in it, we can make it rebuild itself *way* faster during
development by using the following steps:

One time setup:

1. Build our container from source the normal way `docker build . -t my_container`
2. Launch this container in the background: `CONTAINER=$(docker run -dit my_container /bin/sh)`

Whenever you change code:

1. Copy any changed code to the container: `docker cp src "${CONTAINER}:src"`
2. Run an incremental build in the container: `docker exec -it "${CONTAINER}" <rebuild-command>`
3. If your build succeeds, then create an image from the live container: `docker commit "${CONTAINER}" my_container`

Now this might be a few more steps than just the docker build, but
they all run really really fast. Of course typing it all out is slow,
so you'll want to create a script to do it for you. I've creatd a
`build.sh` to streamline this whole process.

Here is how you can try it out:

1. Run `build.sh` you should see your source code build for the first
   time.

2. Run `docker images poc_container` and note the `CREATED` value.

3. Run `build.sh` again, and you should see the build be much faster.

4. Edit `src/main/java/Library.java` and run `build.sh` again.

5. Run `docker images poc_container` and note the `CREATED` value. You
   should see that your container was incremently rebuilt super quickly.

5. Run `docker ps` and you will see the `builder` container in the
   background. This is where your builds are happening and your
   incremental build state is preserved. You can run `docker attach
   builder` if you want to run commands inside this container. *Note:*
   Use `C-p C-q` to detach.

5. Run `build.sh clean` to cleanup the background container.

That's it! Using this technique you should be able to produce
development containers as quickly and as frequently as you rebuild
your code.

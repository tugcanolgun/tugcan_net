---
title: Vigilio
type: page
topic: article
---

I have published my project [Vigilio](https://github.com/tugcanolgun/vigilio) some time ago. It is an open source personal streaming service that you can run on your server and host your movies. It has many similar features to known streaming services except the part that it does not have a mobile app or a TV app. If you are okay with only using a service via web browser (both desktop and mobile), then I believe you will find something useful in this project. 

I want to talk about how it all started and what difficulties I encountered and how I solved them.

# Initial experimentation

Before I started any of this, I experimented with such an idea. I uploaded a video to my server and just opened the link to it and it didn't play. I learnt later that it didn't play because if you want to play a video on your browser, it needs to be in a specific format, container and codec. I searched to see how I can convert this mkv file to mp4. I found out that I can do this with a tool called [ffmpeg](https://ffmpeg.org/). So I converted the container of this video to mp4. The link started working. I was able to watch this video via direct link. 

Watching it like this was good and all, but I usually watch videos with subtitles. The browser's direct video playing capability does not support this feature. I searched a little bit and found out about [videojs](https://videojs.com/). So, I made this static html page to play this video on and it worked. 

I wanted to add subtitles to this video. I downloaded a few and uploaded to the server, added to videojs on that html page. To my surprise, it did not work. Turns out, if you want subtitles that would work with videojs, you need the [webvtt](https://www.w3.org/TR/webvtt1/) format. So I went ahead and found srt to webvtt script, which is a simple command line program to convert srt files to vtt files. I used it to convert the subtitle file. I added the newly created vtt file to the html page and voilà! It works!

Now what? I thought, why not make this process autonomous? Okay, how should I do this? One way of achieving this would be to write a command line script. You run this tool with the video in mind, maybe add a few more parameters and it would convert the video, find subtitles, convert them, rename everything. Another, better way of doing this is to achieve this via web interface. It would be easier to go to a url instead of connecting to the server via ssh every time. Since I know [django](https://www.djangoproject.com/) the best, why not build a project with it.

# Torrent management

I started building the project with django. First order of business was to handle torrent management. The download should start automagically. Thankfully, there is a library called [python-qbittorrent](https://github.com/v1k45/python-qbittorrent) that acts as a wrapper to communicate with qbittorrent's API. However, there was a problem. 

Starting to download a file is easy, but keeping the track of it is not. Once you start a download, it doesn't return anything related to what it started. No hash, no id, no nothing. There is a possibility of keeping track of it via creation date but what if there are two requests at the same time? Which one belongs to which? Another way of keeping track of it is via categories feature of qbittorrent. If you create a category with the id of a table in the database and add this torrent to that category, since id will always be unique, that category will always belong to this download and will always contain one. 

I must say that there is actually a better way to do this. I could extract the hash from .torrent file or magnet via bencode as shown here, but this seemed like more work and I was only doing this as a prototype for myself only. So I chose the easy way.

# Keeping track of the download

Now that I can start downloading things and can track which one belongs to which, I need to know when that download finishes. There is no direct way to do this via vanilla django, but one of the most popular tools, [celery](https://docs.celeryq.dev/en/stable/), can do this. 

After a download starts, a celery process is initiated. I don't want to keep this process alive all the time and check it all the time because if there may be a celery process limit, this may create delays. So, a process is waking up, checking the status of the tracked download and repeats if it is not 100% yet.

# Movie information

I can now manage downloads. What's next? I've always liked the idea that you can see posters of movies along with imdb score and other related information. So, I wrote a celery process, just like the one mentioned above. It gets the information from [moviedb](https://www.themoviedb.org/) and adds it to the database.

# Processing the video

This one was straightforward. After the download is finished, all I needed to do was to change the container of the video with ffmpeg like I mentioned. Only, I don't want the name to persist. 

I am going to run this website on my server with an SSL, thus the content of what I am watching should be hidden from 3rd parties. What about the url itself? I don't want any 3rd party to know that I am reaching to coffee-run-blender-open-movie.mp4. In order to prevent this, I wrote a basic hashing algorithm and used that as the output of this conversion with ffmpeg. So the result of the mentioned file name could now be: 6dda1943eb86a4c4.mp4. 

# Getting subtitles

Getting the subtitles was straightforward. I used [opensubtitles](https://www.opensubtitles.org) to get the them. Opensubtitles use a hashing algorithm to detect the content. It does not rely on the name of the file. The hashing algorithm is publicly available. So I acquired the hash of the downloaded (or converted) video and download them from opensubtitles. 

As a fail safe method I did try to get the subtitles from the most safe way to less safe way.

```
1. movie_byte_size + movie_hash + imdb + language
2. file_name + imdb + language
3. imdb + language
```

It tries to get it with the subtitles with the first one, if there are no results, moves to the next.

One issue was related to the encoding of the subtitles. Once a srt file is downloaded and it is about to be converted, the way that the file is read may affect letters in many languages. Due to that, I tried to capture the encoding and read the file according to that. Converting the srt files to vtt was straightforward. A tiny bash script using sed did the job perfectly.

```
00:01.000 --> 00:04.000
00:01.100 --> 00:04.400
- Never drink liquid nitrogen.
```

Unfortunately, Opensubtitles has advertisements in the subtitles. Some of those subtitles are shown as Some advert --> The best. This is exactly how vtt files work and they expect time signatures instead of letters. This is a bad ad design and I don't know why Opensubtitles show advertisements this way. In fact, videojs does think that this is a time signature and throws an error. So in this conversion, I also got rid of --> symbols that are not timings.

# Adding a movie

Now that the downloading and converting side of background processes can be handled automatically, I needed an interface to start these downloads. I wrote a very basic page with a form. You need to enter an imdb ID and a torrent source. This function still exists, granted a few style changes.

# Interface

Functionally everything was working and it was time to start thinking about the layout. There are many streaming services out there, many of which have similar layouts to one another. I wanted my interface to be looking alike so the users would be familiar with it but not a direct copy of an existing one.

Django has a very powerful template engine. I can use it to create a good interface. Although, I wanted to learn react library a little bit more. 

I have some experience with react-native. I wrote Nerde Kaldi app for Ambeent Inc. while I was working there. I also wrote a few features for Codility. 

I wanted to get some web experience as well. At the same time, I did not want to create a single page app. So, I created views for individual pages and mounted react components directly. I also went ahead and used splitChunks plugin for webpack to separate bundles so the user wouldn't have to download everything that the website needs, just the part that it's used. 

I started coding by using function components instead of class components. I haven't touched react since the hooks were introduced. I must say I love the simplicity.

# Modern? and Simple

Some open-source projects have the tendency of complicating things. I understand the notion, customization is one of the selling points of these products. You can customize each color, each pixel in some cases but the software's default appearance looks outdated even in the 90s. 

There are also other projects, which look modern and great. I am currently using Manjaro with gnome desktop. I must say, it looks as good as any professionally developed software.

So, my aim is to create a modern looking interface but it should be simple. I wanted as little options as possible to run this software. Adding a movie should be easy. Downloading subtitles should be easy. Everything should be presented with maximum information without cluttering the look. However, I also added lots of other options, if the user ever needs them. I believe the look of the website turned out to be quite okay,

![Screenshot of home page](https://user-images.githubusercontent.com/18149492/112493302-5407e300-8d82-11eb-8966-12a4757dc043.jpg "home page screenshot")

The only gripe that I have is adding new search sources. The first time a user installs Vigilio, several steps are required to add a search source. Though it is not simple, the user needs to do this only once. Speaking of search sources, I must say why I have opted for such an option.

# Adding movies by searching

While building the project, I have shown it to several people. One of the most requested features was to add a movie by just searching. So, I added a screen so the users could just type the name of the movie and click download, instead of finding a torrent and finding the imdb id of the movie.

![Screenshot of search functionality](https://user-images.githubusercontent.com/18149492/112493327-59fdc400-8d82-11eb-93f1-990459f3fd48.jpg "search functionality")

# Legality of giving access to movie searching

As I was creating this feature, I started having this feeling that I may get in trouble if I publish it with searchable torrents. So in theory, I want to give the users the ability to search movies and download, but also I do not want to give this functionality built-in as this may somehow create a problem. At first, I thought that I would just leave the API address empty and provide a setting that the user can enter the API address to be used, but then I thought that it would be too limited. I know what this particular API returns, but what about another API that the user may want to add? So, I paused my project and started searching for a solution. 

I started writing something that would take the result of an API and parse it into a known schema. I honestly did not research a lot to see if such a solution is available, but the little time that I did, I could not find one. The reason behind this is the fact that a simple word, mapper, did not occur to me. Had I thought of it, I could have used some of the existing libraries and saved some time. So, I started writing this and published it as [mud-parser](https://www.npmjs.com/package/mud-parser). Provided that it has some shortcomings, it is a neat idea. You create a schema (or get an already created one) and this schema is used to map that particular API to your needs. Thus, you can use multiple APIs for your project without the need to adjust it for individual APIs.

Even though I was reinventing the wheel on this by missing the already existing libraries, I am really happy with the result as it gave me a lot of experience and I have learnt a lot. By completing such a library, I needed a platform for users to create new schemas and get the existing schemas. So I built [vigilio-sources](https://vigiliosources.docaine.com/). You can reach the live website here. Building this interface did not take me too long. It is not very feature rich but it works. Now the users can get existing API sources and create new sources. It also has a scoring system. You can thumb up or down a source.

Well, after working on mud-parser and vigilio-sources in a total of two weeks, it is up to the users which source would be added as a source and the responsibility of choosing a source is up to them. Also, the sources are added by users. It is up to the users to find and choose a legal source.

# Documentation

I always liked good documentation. I also never used readthedocs. So I started writing some documentation about Vigilio and it is available at [docs.vigilio.tugcan.net](https://docs.vigilio.tugcan.net/en/latest/).

# A landing page

I wanted to create a landing page for vigilio. It is not a necessary thing but I always liked them. So, I created a simple page with links to a demo, documentation and the github page. It is available at [vigilio.tugcan.net](https://vigilio.tugcan.net).

![Screenshot vigilio landing page](https://user-images.githubusercontent.com/18149492/112493327-59fdc400-8d82-11eb-93f1-990459f3fd48.jpg "vigilio landing page")

# Demo

Speaking of demo, I wanted to create a demo mode so that I can showcase this product to people without the risk of someone deleting/adding movies or breaking the system settings. So, I added a demo tag in the settings and added this as a check before important endpoints, meaning if the demo mode is active, you cannot add/delete/edit things. 

Unfortunately, this wasn't enough. I needed another functionality if I wanted this mode to work. Normally, the views require authenticated users or it will redirect the user to the login page. I do not want to force people to log in with a fake name. Instead, I wanted a system where a temporary user would be created on the fly and deleted several hours later. The temporary user part is important because the user who is testing this product may want to add movies to a list, start watching movies and may want to see how continue watching functionality works. 

There is an abandoned library for this called django-lazysignup. Although, it does not work with recent django versions. I forked the library and fixed the problems and compatibility issues. It now works with creating temporary users on the fly. I must say that I am happy with the result.

A live demo of Vigilio can be found at [demo.vigilio.tugcan.net](https://demo.vigilio.tugcan.net/).

# The name

As to why I chose the name vigilio is a little bit embarrassing. My wife and I started searching for star names, galaxy names, old gods and some latin words. Nothing fit to what I wanted. I wanted a unique name and I wanted this name to sound good. After going through maybe 300 names and checking if a software exists with these names took a long time. 

While I was searching latin words, I came across vigilio. At first glance, I thought it meant watch as in to watch a play, but later I've learnt that vigilio comes from the word vigilar, to monitor, watch over, patrol, pay attention.

Granted, this would not be the first choice, have I noticed the meaning earlier. Although, it is not all bad. This meaning is also related as in watching over your privacy, the tools you use. 

My wife and I asked vigilio and another candidate, which I won't utter here to 9 of our friends from different nationalities: British, Polish, Turkish, Albanian, Russian and Italian. Except Turks, all of whom prefered vigilio and all of them were able to spell it without an issue. 

I know Vigilio is also a male name, but it sounds good to me so I decided to go for it.

# Other features

I will not bore with the details of why or how I added other features. Although I want to mention simply what those other features are:

* My list feature that the users can add and remove movies to and from their list.
* Continue watching feature.
* Initial setup page.
* User history page, which shows the user's history as a list with the ability to delete them.
    * Background management page:
    * View active torrents.
    * Force start, continue, pause and delete torrents.
* View and remove background processes.
* A background process checker to make sure before adding a movie, redis server, qbittorrent and celery services are running.
* A settings page:
    * Configure environment variables.
    * Re-download subtitles.
    * Set movieDB API key.
    * Select subtitle languages.
    * Add/remove search sources.
* Movie details page:
    * Movie info section to see details of the movie.
    * Add/remove movies to/from my list.
    * Remove a movie from continue watching list.
    * Remove the movie and everything associated with it.
    * View and remove files associated with the movie.

# Conclusion

This project took me almost 2 months to create, 59 days. I am really proud of what I have achieved here. The problems that I have encountered made me learn quite a deal about aspects of languages and libraries that I was using. 

If you like Vigilio, you can help the project via the following ways:

* You can give a star to the repo.
* Blog or tweet about the project.
* Discuss potential ways to improve the project or implement them.



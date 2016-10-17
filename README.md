##Introduction

A couple of years ago, I got it into my head that I wanted a sort of basic law library. And it turns out that for primary law at least, everything is out there to be viewed, but only some of it can be downloaded easily. If you want US Code Title 6, you can download that as one (or possibly several PDFs). But other parts of law aren't so easily downloaded.

For instance, the Texas Administrative Code. This set of rules aren't statutory law, more like internal policies of the various bureaus and departments of the state of Texas. You can view them online, but even Title 1 (there are 15 other titles) is 3800 separate pages. You can only view one page at a time, and you must click a button to see the next page. Many of these pages consist of only a sentence or two.

I started by writing an awful bash script that invoked perl about a million times (because sed sucks), and while it was an abomination of code, it did let me prototype the idea. This is Mark II, pure perl. There are numerous improvements. It uses WWW::Mechanize instead of wget, which means the code doesn't have to be twisted into a knot to follow the correct links. I've modularized this so that I can add other bodies of law eventually. Downloading, compiling, rendering are cleanly separated. And soon I'll be adding both a command-line switch and interactive interface.

What I'd like for this to become is a single application that you fire up, answer a few questions and it downloads anything you've told it to download. Or that you can chuck into cron and have it download the new version of the Code of Federal Regulations every year. PDF will be the default output format, but html at least will be an option (since that's the intermediary format being used here).

## To Do
1. Everything

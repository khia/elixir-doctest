APP=$(shell ls src/*.app.src | sed -e 's/src\///g' | sed -e 's/.app.src//g')
NODE=$(subst .,_,$(APP))
ERL_ROOT=`erl -noshell -eval 'io:format("~s\n", [code:root_dir()]), init:stop().'`
ERL_INTERFACE = `erl -noshell -eval 'io:format("~s\n", [filelib:wildcard(filename:join([code:root_dir(), "lib/erl_interface-*"]))]), init:stop().'`
ERL_ERTS = `erl -noshell -eval 'io:format("~s\n", [filelib:wildcard(filename:join([code:root_dir(), "erts-*"]))]), init:stop().'`
ELIXIR_PATH = `elixir -e 'IO.puts File.dirname File.expand_path(:code.which(:elixir))'`

all: compile

tup = $(shell which tup)
tup:
ifeq ($(notdir ${tup}),tup)
	@ln -s ${tup} tup
else
	$(eval TMP := $(shell mktemp -d))
	$(eval TOP := $(shell pwd))
	git clone https://github.com/gittup/tup.git ${TMP} ; cd ${TMP} && ./bootstrap.sh && cp ${TMP}/tup ${TOP}/
endif

.tup: tup
	tup init
	rm -f ebin/*.beam ebin/*.app

deps: .tup

compile: deps
	tup upd

test: compile
	ERL_FLAGS="-pa $(ELIXIR_PATH) -pa ebin/" elixir test/exunit.exs -- +doctest

iex: compile
	ERL_FLAGS="-pa $(ELIXIR_PATH) -pa ebin/" iex
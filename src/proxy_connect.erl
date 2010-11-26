%%% -------------------------------------------------------------------
%%% Author  : skruger
%%% Description :
%%%
%%% Created : Nov 5, 2010
%%% -------------------------------------------------------------------
-module(proxy_connect).

%% -behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

-include("surrogate.hrl").

%% --------------------------------------------------------------------
%% External exports
-export([client_loop/2,server_loop/2,http_connect/1,socks5_connect/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {}).

%% ====================================================================
%% External functions
%% ====================================================================

http_connect(ProxyPass) ->
	{ok,Host,Port} = proxylib:parse_connect(ProxyPass#proxy_pass.request),
	case gen_tcp:connect(Host,Port,[binary,{active,false}]) of
		{ok,SvrSock} ->
			ServerPid = spawn(?MODULE,server_loop,[SvrSock,undefined]),
			ClientPid = spawn(?MODULE,client_loop,[ProxyPass#proxy_pass.client_sock,undefined]),
			gen_tcp:send(ProxyPass#proxy_pass.client_sock,<<"HTTP/1.0 200 Connection Established\r\n\r\n">>),
			gen_tcp:controlling_process(SvrSock,ServerPid),
			gen_tcp:controlling_process(ProxyPass#proxy_pass.client_sock,ClientPid),
			ServerPid ! {client,ClientPid},
			ClientPid ! {server,ServerPid},
			ok;
		{error,ErrStat} = Err ->
			gen_fsm:send_event(self(),{error,503,lists:flatten(io_lib:format("Error connecting to server: ~p",[ErrStat]))}),
			Err
	end.
			

%% 	?ACCESS_LOG(RCode,State#proxy_pass.request,State#proxy_pass.userinfo,SvrHeader#proxy_pass.request); 

socks5_connect(ClientSock,ServerSock) ->
	ServerPid = spawn(?MODULE,server_loop,[ServerSock,undefined]),
	ClientPid = spawn(?MODULE,client_loop,[ClientSock,undefined]),
	gen_tcp:controlling_process(ServerSock,ServerPid),
	gen_tcp:controlling_process(ClientSock,ClientPid),
	ServerPid ! {client,ClientPid},
	ClientPid ! {server,ServerPid},
	ok.
	
  

%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
    {ok, #state{}}.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

client_loop(ClientSock,ServerPid) when ServerPid == undefined ->
	receive
		{server,Pid} ->
			inet:setopts(ClientSock,[{active,once}]),
			client_loop(ClientSock,Pid);
		_ ->
			client_loop(ClientSock,ServerPid)
	end;
client_loop(Sock,SvrPid) ->
	receive
		{tcp,Sock,Data} ->
			inet:setopts(Sock,[{active,once}]),
			SvrPid ! {client_tcp,Data},
			client_loop(Sock,SvrPid);
		{server_tcp,Data} ->
			gen_tcp:send(Sock,Data),
			client_loop(Sock,SvrPid);
		{tcp_closed,Sock} ->
			SvrPid ! client_closed,
			ok;
		server_closed ->
			gen_tcp:close(Sock),
			ok;
		{tcp_error,Sock,Reason} ->
			?DEBUG_MSG("Socket closed: ~p~n",[Reason]),
			SvrPid ! client_closed
	end.
		
server_loop(ServerSock,ClientPid) when ClientPid == undefined ->
	receive
		{client,Pid} ->
			inet:setopts(ServerSock,[{active,once}]),
			server_loop(ServerSock,Pid);
		_ ->
			server_loop(ServerSock,ClientPid)
	end;
server_loop(Sock,CliPid) ->
	receive
		{tcp,Sock,Data} ->
			inet:setopts(Sock,[{active,once}]),
			CliPid ! {server_tcp,Data},
			server_loop(Sock,CliPid);
		{client_tcp,Data} ->
			gen_tcp:send(Sock,Data),
			server_loop(Sock,CliPid);
		{tcp_closed,Sock} ->
			CliPid ! server_closed,
			ok;
		client_closed ->
			gen_tcp:close(Sock),
			ok;
		{tcp_error,Sock,Reason} ->
			?DEBUG_MSG("Server socket closed: ~p~n",[Reason]),
			CliPid ! server_closed
	end.

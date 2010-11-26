
-record(proxy_listener,{listen_sock,parent_pid}).

-record(request_rec,{proxytype,method,path,protocol,host,state,port}).
-record(response_rec,{protocol,code,text}).

-record(proxy_pass,{server_sock,client_sock,request,headers,recv_buff,proxy_type,userinfo,csock_mod}).

-record(filter_check,{hosts,urls}).

-record(proxy_user,{username,host,auth_method}).


-record(filter_host_list,{host,rule}).
-record(filter_url_list,{host,path,rule}).

-record(proxy_userinfo,{username,password}).

-define(CRITICAL(X,Y), surrogate_log:append(0,?MODULE,lists:flatten(io_lib:format(X,Y)))).
-define(ERROR_MSG(X,Y), surrogate_log:append(1,?MODULE,lists:flatten(io_lib:format(X,Y)))).
-define(WARN_MSG(X,Y), surrogate_log:append(2,?MODULE,lists:flatten(io_lib:format(X,Y)))).
-define(INFO_MSG(X,Y), surrogate_log:append(3,?MODULE,lists:flatten(io_lib:format(X,Y)))).
-define(DEBUG_MSG(X,Y), surrogate_log:append(4,?MODULE,lists:flatten(io_lib:format(X,Y)))).

-define(ACCESS_LOG(C,P,U,X), surrogate_log:access(C,P,U,X)).
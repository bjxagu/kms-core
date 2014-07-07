${remoteClass.name}ImplInternal.cpp
#include <gst/gst.h>
<#list remoteClassDependencies(remoteClass) as dependency>
<#if model.remoteClasses?seq_contains(dependency)>
#include "${dependency.name}Impl.hpp"
<#else>
#include "${dependency.name}.hpp"
</#if>
</#list>
#include "${remoteClass.name}Impl.hpp"
#include "${remoteClass.name}Internal.hpp"
#include <jsonrpc/JsonSerializer.hpp>
#include <KurentoException.hpp>

namespace kurento
{
<#if (!remoteClass.abstract) && (remoteClass.constructors[0])??>

MediaObjectImpl *${remoteClass.name}Impl::Factory::createObjectPointer (const Json::Value &params) const
{
  <#list remoteClass.constructors[0].params as param>
  <#if model.remoteClasses?seq_contains(param.type.type)><#lt>
  ${getCppObjectType(param.type, false, "", "Impl")} ${param.name}<#rt>
  <#else><#lt>
  ${getCppObjectType(param.type, false)} ${param.name}<#rt>
  </#if>
    <#lt><#if param.type.name = "int"> = 0<#rt>
    <#lt><#elseif param.type.name = "boolean"> = false<#rt>
    <#lt><#elseif param.type.name = "float"> = 0.0<#rt>
    <#lt></#if>;
  </#list>

  <#list remoteClass.constructors[0].params as param>
  if (!params.isMember ("${param.name}") ) {
    <#if (param.defaultValue)??>
    /* param '${param.name}' not present, using default */
    <#if param.type.name = "String" || param.type.name = "int" || param.type.name = "boolean">
    ${param.name} = ${param.defaultValue};
    <#elseif model.complexTypes?seq_contains(param.type.type) >
      <#if param.type.type.typeFormat == "REGISTER">
    // TODO, deserialize default param value for type '${param.type}'
      <#elseif param.type.type.typeFormat == "ENUM">
    ${param.name} = std::shared_ptr<${param.type.name}> (new ${param.type.name} (${param.defaultValue}) );
      <#else>
    // TODO, deserialize default param value for type '${param.type}' not expected
      </#if>
    <#else>
    // TODO, deserialize default param value for type '${param.type}'
    </#if>
    <#else>
    <#if (param.optional)>
    // Warning, optional constructor parameter '${param.name}' but no default value provided
    <#else>
    /* param '${param.name}' not present, raise exception */
    JsonRpc::CallException e (JsonRpc::ErrorCode::SERVER_ERROR_INIT,
                              "'${param.name}' parameter is requiered");
    throw e;
    </#if>
    </#if>
  } else {
    JsonSerializer s (false);
    s.JsonValue = params;
    s.SerializeNVP (${param.name});
  }

  </#list>
  return createObject (<#rt>
     <#lt><#list remoteClass.constructors[0].params as param><#rt>
        <#lt>${param.name}<#rt>
        <#lt><#if param_has_next>, </#if><#rt>
     <#lt></#list>);
}
</#if>

void
${remoteClass.name}Impl::invoke (std::shared_ptr<MediaObjectImpl> obj, const std::string &methodName, const Json::Value &params, Json::Value &response)
{
<#list remoteClass.methods as method>
  if (methodName == "${method.name}") {
    kurento::JsonSerializer s (false);
    ${remoteClass.name}Method${method.name?cap_first} method;
    <#if method.return??>
    JsonSerializer responseSerializer (true);
    ${getCppObjectType(method.return.type, false)} ret;
    </#if>

    s.JsonValue = params;
    method.Serialize (s);

    <#if method.return??>
    ret = <#rt>
    <#else><#rt>
    </#if>method.invoke (std::dynamic_pointer_cast<${remoteClass.name}> (obj) );
    <#if method.return??>
    responseSerializer.SerializeNVP (ret);
    response = responseSerializer.JsonValue["ret"];
    </#if>
    return;
  }

</#list>
<#if (remoteClass.extends)??>
  ${remoteClass.extends.name}Impl::invoke (obj, methodName, params, response);
<#else>
  JsonRpc::CallException e (JsonRpc::ErrorCode::SERVER_ERROR_INIT,
                            "Method '" + methodName + "' with " + std::to_string (params.size() ) + " parameters not found");
  throw e;
</#if>
}

bool
${remoteClass.name}Impl::connect (const std::string &eventType, std::shared_ptr<EventHandler> handler)
{
<#list remoteClass.events as event>

  if ("${event.name}" == eventType) {
    sigc::connection conn = signal${event.name}.connect ([ &, handler] (${event.name} event) {
      JsonSerializer s (true);

      s.Serialize ("data", event);
      s.Serialize ("object", this);
      s.JsonValue["type"] = "${event.name}";
      handler->sendEvent (s.JsonValue);
    });
    handler->setConnection (conn);
    return true;
  }
</#list>

<#if (remoteClass.extends)??>
  return ${remoteClass.extends.name}Impl::connect (eventType, handler);
<#else>
  return false;
</#if>
}

void
Serialize (std::shared_ptr<kurento::${remoteClass.name}Impl> &object, JsonSerializer &serializer)
{
  if (serializer.IsWriter) {
    if (object) {
      object->Serialize (serializer);
    }
  } else {
    try {
      std::shared_ptr<kurento::MediaObjectImpl> aux;
      aux = kurento::${remoteClass.name}Impl::Factory::getObject (serializer.JsonValue.asString () );
      object = std::dynamic_pointer_cast<kurento::${remoteClass.name}Impl> (aux);
      return;
    } catch (KurentoException &ex) {
      throw KurentoException (MARSHALL_ERROR,
                              "'${remoteClass.name}Impl' object not found: " + ex.getMessage() );
    }
  }
}

void
${remoteClass.name}Impl::Serialize (JsonSerializer &serializer)
{
  if (serializer.IsWriter) {
    try {
      Json::Value v (getId() );

      serializer.JsonValue = v;
    } catch (std::bad_cast &e) {
    }
  } else {
    try {
      std::shared_ptr<kurento::MediaObjectImpl> aux;
      aux = kurento::${remoteClass.name}Impl::Factory::getObject (serializer.JsonValue.asString () );
      *this = *std::dynamic_pointer_cast<kurento::${remoteClass.name}Impl> (aux).get();
      return;
    } catch (KurentoException &ex) {
      throw KurentoException (MARSHALL_ERROR,
                              "'${remoteClass.name}Impl' object not found: " + ex.getMessage() );
    }
  }
}

void
Serialize (std::shared_ptr<kurento::${remoteClass.name}> &object, JsonSerializer &serializer)
{
  std::shared_ptr<kurento::${remoteClass.name}Impl> aux = std::dynamic_pointer_cast<kurento::${remoteClass.name}Impl> (object);

  Serialize (aux, serializer);
}

} /* kurento */
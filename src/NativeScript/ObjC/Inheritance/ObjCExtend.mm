//
//  ObjCExtend.mm
//  NativeScript
//
//  Created by Yavor Georgiev on 24.07.14.
//  Copyright (c) 2014 г. Telerik. All rights reserved.
//

#include "ObjCExtend.h"
#include "ObjCClassBuilder.h"
#include "ObjCConstructorDerived.h"

namespace NativeScript {
using namespace JSC;
using namespace Metadata;

EncodedJSValue JSC_HOST_CALL ObjCExtendFunction(ExecState* execState) {
    JSValue baseConstructor = execState->thisValue();
    JSC::VM& vm = execState->vm();
    auto scope = DECLARE_THROW_SCOPE(vm);

    JSValue instanceMethodsValue = execState->argument(0);
    if (!instanceMethodsValue.inherits(vm, JSObject::info())) {
        return JSValue::encode(scope.throwException(execState, createError(execState, instanceMethodsValue, "must be an object"_s, defaultSourceAppender)));
    }
    if (instanceMethodsValue.get(execState, execState->vm().propertyNames->constructor).inherits(vm, ObjCConstructorBase::info())) {
        return JSValue::encode(scope.throwException(execState, createError(execState, "The override object is used by another derived class"_s, defaultSourceAppender)));
    }
    JSObject* instanceMethods = instanceMethodsValue.toObject(execState);

    WTF::String className = emptyString();
    JSValue exposedMethods = jsUndefined();
    JSValue protocolsArray = jsUndefined();

    if (!execState->argument(1).isUndefinedOrNull()) {
        JSValue inheritInfo = execState->argument(1);
        JSValue classNameValue = inheritInfo.get(execState, execState->vm().propertyNames->name);
        if (!classNameValue.isUndefined()) {
            className = classNameValue.toString(execState)->value(execState);
        }
        exposedMethods = inheritInfo.get(execState, Identifier::fromString(execState, "exposedMethods"));
        protocolsArray = inheritInfo.get(execState, Identifier::fromString(execState, "protocols"));
    }

    ObjCClassBuilder classBuilder(execState, baseConstructor, instanceMethods, className);
    if (scope.exception()) {
        return JSValue::encode(jsUndefined());
    }

    classBuilder.implementProtocols(execState, protocolsArray);
    if (scope.exception()) {
        return JSValue::encode(jsUndefined());
    }

    classBuilder.addInstanceMembers(execState, instanceMethods, exposedMethods);
    if (scope.exception()) {
        return JSValue::encode(jsUndefined());
    }

    ObjCConstructorDerived* constructor = classBuilder.build(execState);
    if (scope.exception()) {
        return JSValue::encode(jsUndefined());
    }

    return JSValue::encode(constructor);
}
}

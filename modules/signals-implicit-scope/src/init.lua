local SignalsImplicitScope = require(script.SignalsImplicitScope)

export type getter<T> = SignalsImplicitScope.getter<T>
export type setter<T> = SignalsImplicitScope.setter<T>
export type update<T> = SignalsImplicitScope.update<T>
export type equals<T> = SignalsImplicitScope.equals<T>
export type dispose = SignalsImplicitScope.dispose

return SignalsImplicitScope

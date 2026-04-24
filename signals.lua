--!strict
local Signals = require(script.Signals)
local SignalsExperimental = require(script.SignalsExperimental)
local SignalsReact = require(script.SignalsReact)

export type getter<T> = Signals.getter<T>
export type setter<T> = Signals.setter<T>
export type update<T> = Signals.update<T>
export type equals<T> = Signals.equals<T>
export type dispose = Signals.dispose

export type scope = Signals.scope

return {
    createSignal = Signals.createSignal,
    createComputed = Signals.createComputed,
    createEffect = Signals.createEffect,

    onDisposed = SignalsExperimental.onDisposed,
    batch = SignalsExperimental.batch,

    useSignalState = SignalsReact.useSignalState,
    useSignalBinding = SignalsReact.useSignalBinding,
}

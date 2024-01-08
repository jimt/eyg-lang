import gleam/io
import lustre/effect
import old_plinth/javascript/promisex
import plinth/javascript/global
import plinth/javascript/date.{type Date}
import plinth/javascript/storage
import facilities/accu_weather/client as accu_weather
import facilities/accu_weather/daily_forecast

pub type State {
  State(now: Date, forecast: List(daily_forecast.DailyForecast))
}

pub fn init(_) {
  let assert Ok(s) = storage.local()
  let accu_weather_key = case storage.get_item(s, "ACCU_WEATHER_KEY") {
    Error(Nil) -> panic("no accu_weather_key")
    Ok(accu_weather_key) -> accu_weather_key
  }

  let state = State(date.now(), [])
  #(
    state,
    effect.batch([
      effect.from(watch_time),
      effect.from(fn(dispatch) {
        let task =
          accu_weather.five_day_forecast(
            accu_weather_key,
            accu_weather.stockholm_key,
          )
        use resolved <- promisex.aside(task)
        let assert Ok(data) = resolved
        dispatch(
          Wrap(fn(state) {
            let State(now: now, ..) = state
            let state = State(..state, forecast: data)
            #(state, effect.none())
          }),
        )
      }),
    ]),
  )
}

pub type Wrap {
  Wrap(fn(State) -> #(State, effect.Effect(Wrap)))
}

pub fn update(state, msg) {
  let Wrap(msg) = msg
  msg(state)
}

// tasks

fn watch_time(dispatch) {
  global.set_timeout(
    fn(_) {
      dispatch(
        Wrap(fn(state) {
          let state = State(..state, now: date.now())
          #(state, effect.from(watch_time))
        }),
      )
    },
    1000,
  )
}

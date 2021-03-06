express  = require 'express'
router = express.Router()
marko = require 'marko'
request = require("request")

yellowBallIcon = "i607"
greenBallIcon = "i606"
redBallIcon = "i605"
skullIcon = "i148"
cloudsIcon = "a2286"


levelIcons =
  Good: greenBallIcon
  Moderate: yellowBallIcon
  "Unhealthy for Sensitive Groups": yellowBallIcon
  Unhealthy: redBallIcon
  "Very Unhealthy": skullIcon
  Hazardous: skullIcon
  Unavailable: yellowBallIcon


currentUrl = "http://www.airnowapi.org/aq/observation/zipCode/current/?format=application/json&distance=25"
forecastUrl = "http://www.airnowapi.org/aq/forecast/zipCode/?format=application/json&distance=25"

zero_pad = (x) ->
  if x < 10 then '0'+x else ''+x

Date::pretty = ->
  d = zero_pad(this.getDate())
  m = zero_pad(this.getMonth() + 1)
  y = this.getFullYear()
  y + '-' + m + '-' + d

Date::tomorrow = ->
  new Date(this.valueOf() + 60*60*24*1000)


module.exports = (app) ->
  app.use '/', router


  router.get '/', (req, res) ->
    indexTemplate = marko.load require.resolve '../views/index.marko'
    indexTemplate.render
      $global: locals: req.app.locals
      title: 'Air Quality Now for LaMetric'
    , res

  router.get '/current', (req, res) ->
    throw  "zip param required" if not req.query.zip?
    zip = req.query.zip
    today = new Date().pretty()
    tomorrow = new Date().tomorrow().pretty()

    request.get  {
      url: "#{forecastUrl}&date=#{today}&zipCode=#{zip}&API_KEY=#{process.env.AIR_NOW_KEY}"
      json: true
    }, (e, r, forecast) ->
      throw e if e?

      request.get  {
        url: "#{currentUrl}&date=#{today}&zipCode=#{zip}&API_KEY=#{process.env.AIR_NOW_KEY}"
        json: true
      }, (e, r, current) ->
        throw e if e?

        if forecast?.length is 0 or current?.length is 0
          res.json
            frames: [
              {
                index: 0
                text: "No results for zip #{zip}"
                icon: skullIcon
              }
            ]
        else
          now = current[0]
          expectedToday = (f for f in forecast when f?.ParameterName in ['O3','PM2.5'] and f?.DateForecast.trim() is today)[0]
          expectedTomorrow = (f for f in forecast when f?.ParameterName in ['O3','PM2.5'] and f?.DateForecast.trim() is tomorrow)[0]

          frames = [
            {
              index: 0
              text: "Air Quality for #{zip} (#{expectedToday?.ReportingArea}, #{expectedToday?.StateCode})"
              icon: cloudsIcon
            }
          ]

          if now
            frames.push {
              index: 1
              text: "Current AQI #{now.AQI} (#{now?.Category?.Name}) today (#{now.ParameterName})"
              icon: levelIcons[now?.Category?.Name || "Unavailable"]
            }

          if expectedToday
            frames.push {
              index: 2
              text: "AQI #{expectedToday.AQI} (#{expectedToday?.Category?.Name}) expected today (#{expectedToday.ParameterName})"
              icon: levelIcons[expectedToday?.Category?.Name || "Unavailable"]
            }

          if expectedTomorrow
            frames.push {
              index: 3
              text: "AQI #{expectedTomorrow?.AQI} (#{expectedTomorrow?.Category?.Name}) expected tomorrow (#{expectedTomorrow.ParameterName})"
              icon: levelIcons[faqiForcastTomorrow?.Category?.Name || "Unavailable"]
            }
          

          res.json
            frames: frames


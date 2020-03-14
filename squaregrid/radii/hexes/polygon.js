ymaps.ready(init);

function rgbToHex(r, g, b) {
	return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
}

function init() {
	var myMap = new ymaps.Map("map", {
		center: [56.79177158, 60.5441967363],
		zoom: 14
	}, {
			searchControlProvider: 'yandex#search',
			projection: ymaps.projection.sphericalMercator
	});

	var n = Object.keys(hexes.corner0).length
	console.log(n + " hexes")
	console.log(hexes)

	var i;
	for (i = 0; i < n; i++) {
		var myGeoObject7 = new ymaps.GeoObject({
			// Описываем геометрию геообъекта.
			geometry: {
				// Тип геометрии - "Многоугольник".
				type: "Polygon",
				// Указываем координаты вершин многоугольника.
				coordinates: [
					// Координаты вершин внешнего контура.
					hexes.corners[i],
				],
				// Задаем правило заливки внутренних контуров по алгоритму "nonZero".
				fillRule: "nonZero"
			},
			// Описываем свойства геообъекта.
			properties:{
				// Содержимое балуна.
				balloonContent: "hex " + hexes.hex_id[i] + ": " + hexes.count[i] + " objects",
			}
		}, {
			// Описываем опции геообъекта.
			// Цвет заливки.
			fillColor: rgbToHex(hexes.count[i], 0, 255 - hexes.count[i]),
			// Цвет обводки.
			strokeColor: '#0000FF',
			// Общая прозрачность (как для заливки, так и для обводки).
			opacity: 0.3,
			// Ширина обводки.
			strokeWidth: 1,
			// Стиль обводки.
			strokeStyle: 'shortdash'
		});

		// Добавляем многоугольник на карту.
		myMap.geoObjects.add(myGeoObject7);
	}
}

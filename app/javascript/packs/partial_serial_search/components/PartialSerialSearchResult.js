/* eslint import/no-unresolved: 0 */

import React, { Fragment } from "react";

const PartialSerialSearchResult = ({bike}) => (
  <li className="bike-box-item">
    <ResultImage bike={bike}/>

    <div className="bike-information">
      <h5 className="title-link">
        <a href={bike.url} target="_blank">
          <strong>
            {[bike.year, bike.manufacturer_name].filter(a => a).join(' ')}
          </strong> {bike.frame_model}
        </a>
      </h5>

      <ul className="attr-list">
        <li>
          <span className="attr-title">Color</span>
          {bike.frame_colors.join(", ")}
        </li>
        <li>
          <span className="attr-title">Serial</span>
          {bike.serial}
        </li>
      </ul>

      <ul className="attr-list">
        <li>
          <span className="attr-title text-danger">
            {bike.stolen ? "Stolen" : "Abandoned"}
          </span>
          <span className="convertTime">{bike.date_stolen_string}</span>
        </li>
        <li>
          <span className="attr-title">Location</span>
          {bike.stolen_location}
        </li>
      </ul>
    </div>

    <pre className="d-none">
      {JSON.stringify(bike)}
    </pre>
  </li>
)

const ResultImage = ({ bike }) => {
  const backgroundStyles = ({ thumb }) => ({
    backgroundSize: "contain",
    backgroundPosition: "left",
    backgroundRepeat: "no-repeat",
    backgroundImage: `url('${thumb}')`
  });

  if (bike.is_stock_img) {
    return (<a href={bike.url} className="bike-list-image" target="_blank">
              <img src={bike.placeholder_image} className="no-image"/>
            </a>);
  }

  return (<a href={bike.url}
             style={backgroundStyles(bike)}
             className="bike-list-image hover-expand"
             target="_blank" />);
}

export default PartialSerialSearchResult;

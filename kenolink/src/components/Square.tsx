import React, { useState } from 'react';
/* eslint-disable no-console */
type Props = {
    value: number;
    setselectedNumbers?: any;
    selectedNumbers?: any;
};


const Square: React.FC<Props> = (props) => {

    const [style, setStyle] = useState("square_de_selected");


    function handleClick(e: React.MouseEvent<HTMLButtonElement>) {

        e.preventDefault();

        if (style === "square_de_selected") {
            setStyle("square_selected")
            props.setselectedNumbers([...props.selectedNumbers, props.value])
        }

        else {
            for (let i = 0; i <= props.selectedNumbers.length; i++) {
                if (props.selectedNumbers[i] === props.value) {
                    props.selectedNumbers.splice(i, 1);
                    i--;
                    console.log("hej")
                }
            }
            setStyle("square_de_selected")
        }
    }


    return (
        <button className={style} onClick={(e) => handleClick(e)} >
            {props.value}
        </button>
    );
};

export default Square;